(in-package :pine.term)

;;;; Terminal buffers: a pine.vt emulator driven by a pty. The reader thread
;;;; only appends bytes to PENDING under a lock; the GTK pump drains PENDING on
;;;; the main thread (drain-terminals) and feeds the emulator, so the term is
;;;; only ever mutated from one thread. Keys go straight to the pty as escape
;;;; sequences via the dispatch hook.

(defstruct (terminal (:constructor %make-terminal))
  buffer
  term
  fd
  pid
  ;; PENDING is a list of raw output chunks (newest first) pushed by the reader
  ;; under LOCK. CARRY holds chunks the drain deferred to a later tick (oldest
  ;; first, only the main thread touches it). Chunks, not one growing string,
  ;; keep appends O(1) instead of O(n^2) under a flood like `find /`.
  (pending nil)
  (carry nil)
  (lock (bordeaux-threads:make-lock))
  reader
  (alive t))

(defparameter *drain-budget* 8192
  "Max output bytes fed to a terminal emulator per render tick, so a flood
does not block the UI thread (the emulator parses ~one frame's worth here).")

(defparameter *carry-cap* (* 4 1024 1024)
  "Max deferred output bytes to keep. Beyond this a flood is dropped oldest-first
so memory and latency stay bounded rather than falling minutes behind.")

(defun terminal-map (client)
  (or (pine.client:terminal-map client)
      (setf (pine.client:terminal-map client) (make-hash-table :test 'eq))))

(defun terminal-for-buffer (buffer)
  (let ((cli (pine.client:current-client)))
    (and buffer (gethash buffer (terminal-map cli)))))

(defun gterm-text (terminal)
  (if terminal (pine.vt:term-dump-to-string (terminal-term terminal)) ""))


;;;; Reader thread + output draining

(defun start-reader (client tobj)
  (declare (ignore client))
  (flet ((reader ()
           (loop
             (let ((s (pine.vt:pty-read-string (terminal-fd tobj) 8192)))
               (if (null s)
                   (progn (setf (terminal-alive tobj) nil) (return))
                   ;; O(1) hand-off; the pump drives redraws on its own timer,
                   ;; so no per-read render signalling (which floods under load).
                   (bordeaux-threads:with-lock-held ((terminal-lock tobj))
                     (push s (terminal-pending tobj))))))))
    (setf (terminal-reader tobj)
          (bordeaux-threads:make-thread #'reader :name "pine-pty-reader"))))

(defun %drain-one (tobj)
  "Feed up to *drain-budget* bytes of TOBJ's pending output into its emulator.
Returns T if anything was processed."
  (let* ((fresh (bordeaux-threads:with-lock-held ((terminal-lock tobj))
                  (prog1 (nreverse (terminal-pending tobj))
                    (setf (terminal-pending tobj) nil))))
         (chunks (nconc (terminal-carry tobj) fresh))
         (budget *drain-budget*)
         (leftover nil)
         (processed nil))
    (setf (terminal-carry tobj) nil)
    (dolist (chunk chunks)
      (if (and (null leftover) (plusp budget))
          (progn
            (handler-case (pine.vt:term-process-output (terminal-term tobj) chunk)
              (error () nil))
            (decf budget (length chunk))
            (setf processed t))
          (push chunk leftover)))
    (when leftover
      (let* ((carry (nreverse leftover))
             (total (reduce #'+ carry :key #'length :initial-value 0)))
        ;; drop oldest chunks if the backlog blows past the cap
        (loop while (and (> total *carry-cap*) (cdr carry))
              do (decf total (length (pop carry))))
        (setf (terminal-carry tobj) carry)))
    processed))

(defun drain-terminals (client)
  "Feed pending pty output into the emulators, bounded per tick. Returns T if
any terminal advanced (so the caller can mark the frame dirty). Runs on the
render (main) thread."
  (let ((any nil))
    (maphash (lambda (buffer tobj)
               (declare (ignore buffer))
               (when (%drain-one tobj) (setf any t)))
             (terminal-map client))
    any))


;;;; Spawning

(defun open-terminal (client buffer &key (rows 24) (cols 80) (command "/bin/sh"))
  (multiple-value-bind (fd pid) (pine.vt:spawn-pty-process command :rows rows :cols cols)
    (when (minusp fd) (error "pty spawn failed"))
    (let* ((term (pine.vt:make-term
                  :width cols :height rows
                  ;; the emulator calls input-fn as (term bytes) when a program
                  ;; queries the terminal (device attrs, cursor pos, colors).
                  :input-fn (lambda (term bytes)
                              (declare (ignore term))
                              (pine.vt:pty-write-string fd bytes))))
           (tobj (%make-terminal :buffer buffer :term term :fd fd :pid pid)))
      (setf (gethash buffer (terminal-map client)) tobj)
      (start-reader client tobj)
      tobj)))

(defun resize-active-terminal (cols rows)
  (let* ((cli (pine.client:current-client))
         (buf (pine.client:current-buffer cli))
         (tobj (and buf (terminal-for-buffer buf))))
    (when tobj
      (pine.vt:term-resize (terminal-term tobj) cols rows)
      (pine.vt:pty-set-size (terminal-fd tobj) rows cols))))


;;;; Input: pine.key -> pty bytes

(defun %key-mods (key)
  (append (when (pine.key:key-ctrl key) '(:ctrl))
          (when (pine.key:key-meta key) '(:meta))
          (when (pine.key:key-shift key) '(:shift))))

(defparameter *named-keys*
  '(("Up" . :up) ("Down" . :down) ("Left" . :left) ("Right" . :right)
    ("Home" . :home) ("End" . :end) ("Prior" . :page-up) ("Next" . :page-down)
    ("Insert" . :insert) ("Delete" . :delete)
    ("Return" . :enter) ("Tab" . :tab) ("Escape" . :escape) ("BackSpace" . :backspace)))

(defun key->pty-bytes (term key)
  (let* ((sym (pine.key:key-sym key))
         (named (cdr (assoc sym *named-keys* :test #'string=))))
    (cond
      (named (pine.vt:key-event-to-escape-sequence term (cons named (%key-mods key))))
      ((= 1 (length sym))
       (let ((ch (char sym 0)))
         (cond
           ((pine.key:key-ctrl key)
            (string (code-char (logand #x1f (char-code (char-upcase ch))))))
           ((pine.key:key-meta key) (format nil "~C~C" #\Escape ch))
           (t sym))))
      (t nil))))

(defun terminal-dispatch (client key)
  "Dispatch hook: in a terminal buffer send KEY to the pty, except C-x which
stays an editor prefix so the user can switch away."
  (let ((tobj (and (pine.client:current-buffer client)
                   (terminal-for-buffer (pine.client:current-buffer client)))))
    (when tobj
      (if (and (pine.key:key-ctrl key) (string= (pine.key:key-sym key) "x"))
          nil
          (progn
            (let ((bytes (key->pty-bytes (terminal-term tobj) key)))
              (when bytes (pine.vt:pty-write-string (terminal-fd tobj) bytes)))
            t)))))

(defun term-write (buffer text)
  (let ((tobj (terminal-for-buffer buffer)))
    (when tobj (pine.vt:pty-write-string (terminal-fd tobj) text))))
