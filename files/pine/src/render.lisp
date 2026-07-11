(in-package :pine.render)

(defun rs@ (key)
  (fset:@ (pine.client:render-state (pine.client:current-client)) key))

(defun rs-update (&rest pairs)
  (let* ((client (pine.client:current-client))
         (rs (pine.client:render-state client)))
    (loop for (k v) on pairs by #'cddr
          do (setf rs (fset:with rs k v)))
    (setf (pine.client:render-state client) rs)))


;;;; Text conversion for tree-sitter

(defun lines-to-string (ls)
  (let* ((n (fset:size ls))
         (total (loop for i from 0 below n
                      sum (length (fset:@ ls i))
                      sum (if (plusp i) 1 0)))
         (result (make-array total :element-type 'base-char))
         (pos 0))
    (dotimes (i n)
      (when (plusp i)
        (setf (aref result pos) #\Newline)
        (incf pos))
      (let ((line (fset:@ ls i)))
        (dotimes (j (length line))
          (let* ((ch (char line j))
                 (code (char-code ch)))
            (setf (aref result pos) (if (<= code 255) (code-char code) #\?))
            (incf pos)))))
    result))


;;;; Tree-sitter parse dispatch

(defun ts-request-parse (buffer-actor snap language)
  (let ((ts-actor (pine.client:ts-actor (pine.client:current-client))))
    (when (and ts-actor snap language (typep snap 'pine.buffer:snapshot))
      (let ((text (lines-to-string (pine.buffer:lines snap))))
        (sento.actor:tell ts-actor
                          (list :parse
                                :text text
                                :language language
                                :reply-to buffer-actor))))))


;;;; Tree-sitter actor (lives on server; shared across clients)

(defun start-ts-actor (server)
  (let ((ts-rt (pine.server:ts-runtime server))
        (sys (pine.server:actor-system server)))
    (when (and ts-rt (pine.ts:ts-loaded-p ts-rt))
      (sento.actor-context:actor-of sys
        :name "ts-parser"
        :receive
        (lambda (msg)
          (case (first msg)
            (:parse
             (destructuring-bind (&key text language reply-to) (rest msg)
               (let ((hl (handler-case
                             (pine.ts:compute-highlights ts-rt language text)
                           (error () nil))))
                 (when reply-to
                   (sento.actor:tell reply-to
                                     (list :highlights :highlights hl))))))))))))


;;;; Renderer actor (per-client)

(defun start-renderer (client)
  (let* ((server (pine.client:server-of client))
         (sys (pine.server:actor-system server)))
    (setf (pine.client:ts-actor client) (start-ts-actor server))
    (let ((renderer
            (sento.actor-context:actor-of sys
                                          :name (format nil "renderer-~a" (gensym "R"))
                                          :state nil
                                          :receive
                                          (let ((cli client))
                                            (lambda (msg)
                                              (let ((pine.client:*client* cli))
                                                (handler-case
                                                    (case (first msg)
                                                      (:snapshot
                                                       (destructuring-bind (&key snapshot) (rest msg)
                                                         (apply-snapshot snapshot)
                                                         (let ((w (pine.client:focused-window cli)))
                                                           (when w
                                                             (let* ((name (pine.buffer:name snapshot))
                                                                    (tick (pine.buffer:tick snapshot))
                                                                    (rs   (pine.client:render-state cli))
                                                                    (ticks (or (fset:@ rs :parsed-ticks)
                                                                               (fset:empty-map)))
                                                                    (last (or (fset:@ ticks name) -1))
                                                                    (mode-name (pine.buffer:buffer-local
                                                                                snapshot :mode :base-mode))
                                                                    (mode (pine.mode:find-mode mode-name))
                                                                    (lang (and mode
                                                                               (pine.mode:ts-language mode))))
                                                               (when (and lang (> tick last))
                                                                 (setf (pine.client:render-state cli)
                                                                       (fset:with rs :parsed-ticks
                                                                                  (fset:with ticks name tick)))
                                                                 (let ((buf (find-buffer-for-snap snapshot)))
                                                                   (when buf
                                                                     (ts-request-parse buf snapshot lang)))))))
                                                         (rs-update :dirty t)))

                                                      (:resize
                                                       (destructuring-bind (&key cols rows) (rest msg)
                                                         (let ((f (pine.client:frame cli)))
                                                           (setf (pine.buffer:frame-cols f) cols
                                                                 (pine.buffer:frame-rows f) rows))
                                                         (relayout)
                                                         (pine.buffer:ensure-frame-cells (pine.client:frame cli))
                                                         (pine.term:resize-active-terminal cols rows)
                                                         (rs-update :dirty t)))

                                                      (:switch-buffer
                                                       (destructuring-bind (&key buffer name) (rest msg)
                                                         (switch-window-buffer buffer name)))

                                                      (:force-render
                                                       (rs-update :dirty t)))
                                                  (error () nil))))))))
      (setf (pine.client:renderer client) renderer)
      renderer)))


;;;; Window management

(defun find-buffer-for-snap (snap)
  (when (typep snap 'pine.buffer:snapshot)
    (let ((snap-name (pine.buffer:name snap)))
      (loop for w in (pine.client:windows (pine.client:current-client))
            when (string= (pine.buffer:window-name w) snap-name)
              return (pine.buffer:buffer-ref w)))))

(defun apply-snapshot (snap)
  (when (typep snap 'pine.buffer:snapshot)
    (let ((snap-name (pine.buffer:name snap)))
      (dolist (w (pine.client:windows (pine.client:current-client)))
        (when (string= (pine.buffer:window-name w) snap-name)
          (setf (pine.buffer:snap w) snap))))))

(defun switch-window-buffer (buf name)
  (let ((w (pine.client:focused-window (pine.client:current-client))))
    (when w
      (setf (pine.buffer:buffer-ref w) buf
            (pine.buffer:window-name w) name
            (pine.buffer:scroll-top w) 0
            (pine.buffer:col w) 0
            (pine.buffer:snap w) nil
            (pine.buffer:win-display w) nil)))
  (rs-update :dirty t))

(defun relayout ()
  (let* ((client (pine.client:current-client))
         (f (pine.client:frame client))
         (cols (pine.buffer:frame-cols f))
         (rows (pine.buffer:frame-rows f)))
    ;; reserve the bottom two rows for the modeline and the echo/minibuffer.
    (dolist (w (pine.client:windows client))
      (setf (pine.buffer:row w) 0
            (pine.buffer:col w) 0
            (pine.buffer:win-width w) cols
            (pine.buffer:win-height w) (max 1 (- rows 2))))))


;;;; Cell emission

(defun parse-hex-color (hex)
  (if (and hex (> (length hex) 6) (char= (char hex 0) #\#))
      (list (parse-integer hex :start 1 :end 3 :radix 16)
            (parse-integer hex :start 3 :end 5 :radix 16)
            (parse-integer hex :start 5 :end 7 :radix 16))
      (list 205 214 244)))

(defun face-rgb (face-name)
  (let ((f (when face-name (pine.buffer:find-face face-name))))
    (if (and f (pine.buffer:fg f))
        (parse-hex-color (pine.buffer:fg f))
        (list 205 214 244))))

(defun build-highlight-table (highlights scroll-top visible-rows)
  (let ((table (make-hash-table)))
    (dolist (h highlights)
      (let ((line (first h)) (sc (second h)) (ec (third h)) (face (fourth h)))
        (when (and (>= line scroll-top) (< line (+ scroll-top visible-rows)))
          (push (list sc ec face) (gethash (- line scroll-top) table)))))
    (maphash (lambda (k v)
               (setf (gethash k table) (nreverse v)))
             table)
    table))

(defun face-priority (face)
  (case face
    (:keyword        10)
    (:function-name   8)
    (:builtin         7)
    (:constant        6)
    (:escape          6)
    (:string          5)
    (:comment         5)
    (:type            4)
    (:variable-param  3)
    (:variable        1)
    (t                0)))

(defun build-face-slots (line-hl line-length)
  (let ((slots (make-array line-length :initial-element nil))
        (prios (make-array line-length :initial-element -1)))
    (dolist (h line-hl)
      (let* ((sc (first h))
             (ec (min (second h) line-length))
             (face (third h))
             (p (face-priority face)))
        (when face
          (loop for c from (max 0 sc) below ec
                when (> p (aref prios c))
                  do (setf (aref slots c) face
                           (aref prios c) p)))))
    slots))

(defun emit-string (f off row str fg &optional bg)
  "Write STR at ROW (col 0..) into F's cells with FG (list r g b) and optional
BG. Returns the new cell offset."
  (let ((cells (pine.buffer:frame-cells f)))
    (loop for i from 0 below (length str)
          for ch = (char-code (char str i))
          do (setf (svref cells (+ off 0)) row
                   (svref cells (+ off 1)) i
                   (svref cells (+ off 2)) ch
                   (svref cells (+ off 3)) (first fg)
                   (svref cells (+ off 4)) (second fg)
                   (svref cells (+ off 5)) (third fg)
                   (svref cells (+ off 6)) (if bg (first bg) -1)
                   (svref cells (+ off 7)) (if bg (second bg) -1)
                   (svref cells (+ off 8)) (if bg (third bg) -1)
                   (svref cells (+ off 9)) nil)
             (incf off 10))
    off))

(defun %pad (str width)
  (let ((s (if (> (length str) width) (subseq str 0 width) str)))
    (concatenate 'string s (make-string (max 0 (- width (length s)))
                                        :initial-element #\Space))))

(defun render-chrome (f off w)
  "Paint the modeline, echo/minibuffer line, and any completion candidates.
Returns the new cell offset."
  (let* ((cols (pine.buffer:frame-cols f))
         (rows (pine.buffer:frame-rows f))
         (mode-row (- rows 2))
         (echo-row (- rows 1))
         (s (pine.buffer:snap w)))
    ;; modeline
    (let* ((mode (pine.mode:current-buffer-mode))
           (line (if (and s (typep s 'pine.buffer:snapshot))
                     (format nil " ~a   ~a   L~d C~d"
                             (pine.buffer:window-name w)
                             (pine.mode:mode-indicator mode)
                             (1+ (pine.buffer:point-line s))
                             (pine.buffer:point-col s))
                     (format nil " ~a" (pine.buffer:window-name w)))))
      (setf off (emit-string f off mode-row (%pad line cols)
                             '(30 30 46) '(180 190 210))))
    ;; completions (just above the echo line)
    (let ((ct (pine.echo:completions-text)))
      (when (and ct (pine.echo:input-active-p))
        (let* ((clines (let ((acc '()) (start 0))
                         (loop for nl = (position #\Newline ct :start start)
                               do (push (subseq ct start (or nl (length ct))) acc)
                               while nl do (setf start (1+ nl)))
                         (nreverse acc)))
               (n (length clines))
               (top (max 0 (- mode-row n))))
          (loop for cl in clines
                for r from top below mode-row
                do (setf off (emit-string f off r (%pad cl cols)
                                          '(205 214 244) '(49 50 68)))))))
    ;; echo / minibuffer line
    (let* ((prompt (pine.echo:input-prompt))
           (text (if prompt
                     (concatenate 'string prompt (pine.echo:input-text))
                     (pine.echo:current-message))))
      (setf off (emit-string f off echo-row (%pad text cols) '(205 214 244)))
      ;; cursor sits in the minibuffer while a prompt is active
      (when prompt
        (setf (pine.buffer:frame-cursor-row f) echo-row
              (pine.buffer:frame-cursor-col f) (length text))))
    off))

(defun %term-rgb (plist key default)
  "Resolve a terminal cell color to an (r g b) list. color-index-to-rgb
returns a vector, SGR truecolor a 3-list."
  (let ((c (getf plist key)))
    (cond ((null c) default)
          ((integerp c) (coerce (pine.vt:color-index-to-rgb c) 'list))
          ((and (vectorp c) (= 3 (length c))) (coerce c 'list))
          ((and (listp c) (= 3 (length c))) c)
          (t default))))

(defun render-terminal-cells (f w tobj)
  "Fill the buffer area of F from the terminal's emulator grid. Returns off."
  (declare (ignore w))
  (let* ((term (pine.term:terminal-term tobj))
         (cells (pine.buffer:frame-cells f))
         (rows (min (pine.vt:term-height term)
                    (max 1 (- (pine.buffer:frame-rows f) 2))))
         (cols (min (pine.vt:term-width term) (pine.buffer:frame-cols f)))
         (off 0))
    (dotimes (y rows)
      (multiple-value-bind (chars faces) (pine.vt:term-render-line term y)
        (let ((cur nil))
          (dotimes (x cols)
            (let ((change (assoc x faces)))
              (when change (setf cur (second change))))
            (let ((fg (%term-rgb cur :fg '(205 214 244)))
                  (bg (%term-rgb cur :bg nil)))
              (setf (svref cells (+ off 0)) y
                    (svref cells (+ off 1)) x
                    (svref cells (+ off 2)) (char-code (char chars x))
                    (svref cells (+ off 3)) (first fg)
                    (svref cells (+ off 4)) (second fg)
                    (svref cells (+ off 5)) (third fg)
                    (svref cells (+ off 6)) (if bg (first bg) -1)
                    (svref cells (+ off 7)) (if bg (second bg) -1)
                    (svref cells (+ off 8)) (if bg (third bg) -1)
                    (svref cells (+ off 9)) nil)
              (incf off 10))))))
    (setf (pine.buffer:frame-cursor-row f)
          (max 0 (min (pine.vt:term-cursor-y term) (1- rows)))
          (pine.buffer:frame-cursor-col f)
          (max 0 (min (pine.vt:term-cursor-x term) (1- cols))))
    off))

(defun %snapshot-region (s)
  "Normalized region (values start-line start-col end-line end-col) from the
mark (buffer meta) and point, or nil when no mark is set."
  (let ((ml (fset:@ (pine.buffer:meta s) :mark-line))
        (mc (fset:@ (pine.buffer:meta s) :mark-col)))
    (when (and ml mc)
      (let ((pl (pine.buffer:point-line s)) (pc (pine.buffer:point-col s)))
        (if (or (< ml pl) (and (= ml pl) (<= mc pc)))
            (values ml mc pl pc)
            (values pl pc ml mc))))))

(defun %in-region-p (region line col)
  (destructuring-bind (sl sc el ec) region
    (cond ((or (< line sl) (> line el)) nil)
          ((= sl el) (and (>= col sc) (< col ec)))
          ((= line sl) (>= col sc))
          ((= line el) (< col ec))
          (t t))))

(defparameter +selection-bg+ '(69 71 90))

(defun render-buffer-to-frame (w)
  (let ((f (pine.client:frame (pine.client:current-client))))
    (pine.buffer:ensure-frame-cells f)
    (let ((tobj (pine.term:terminal-for-buffer (pine.buffer:buffer-ref w))))
      (when tobj
        (let ((off (render-chrome f (render-terminal-cells f w tobj) w)))
          (setf (pine.buffer:frame-cell-count f) off
                (pine.buffer:frame-dirtyp f) t))
        (return-from render-buffer-to-frame)))
    ;; SNAP is read once: a buffer switch can null it from the renderer thread
    ;; mid-paint, so treat a missing snapshot as an empty buffer (chrome still
    ;; paints) rather than dereferencing nil.
    (let* ((s (pine.buffer:snap w))
           (dl (and s (pine.buffer:win-display w)))
           (wid (pine.buffer:win-width w))
           (cells (pine.buffer:frame-cells f))
           (left (pine.buffer:col w))
           (hl (and s (pine.buffer:highlights s)))
           (hl-table (when hl
                       (build-highlight-table hl (pine.buffer:scroll-top w) (length dl))))
           (region (when s (multiple-value-bind (sl sc el ec) (%snapshot-region s)
                             (when sl (list sl sc el ec)))))
           (off 0))
      (when s
        (loop for d in dl
              for display-row from 0
              for row = (+ (pine.buffer:row w) display-row)
              for text = (pine.buffer:display-text d)
              for buf-line-idx = (+ display-row (pine.buffer:scroll-top w))
              do (let* ((line-hl (when hl-table (gethash display-row hl-table)))
                        (buf-line-len (if (< buf-line-idx (pine.buffer:line-count s))
                                          (length (fset:@ (pine.buffer:lines s) buf-line-idx))
                                          0))
                        (face-slots (when line-hl
                                      (build-face-slots line-hl buf-line-len))))
                   (loop for i from 0 below (min (length text) wid)
                         for ch = (char-code (char text i))
                         for col = i
                         for buf-col = (+ i left)
                         for face = (when (and face-slots (< buf-col (length face-slots)))
                                      (aref face-slots buf-col))
                         for rgb = (face-rgb face)
                         for bg = (when (and region (%in-region-p region buf-line-idx buf-col))
                                    +selection-bg+)
                         do (setf (svref cells (+ off 0)) row
                                  (svref cells (+ off 1)) col
                                  (svref cells (+ off 2)) ch
                                  (svref cells (+ off 3)) (first rgb)
                                  (svref cells (+ off 4)) (second rgb)
                                  (svref cells (+ off 5)) (third rgb)
                                  (svref cells (+ off 6)) (if bg (first bg) -1)
                                  (svref cells (+ off 7)) (if bg (second bg) -1)
                                  (svref cells (+ off 8)) (if bg (third bg) -1)
                                  (svref cells (+ off 9)) nil)
                            (incf off 10))))
        (setf (pine.buffer:frame-cursor-row f)
              (max 0 (min (- (pine.buffer:point-line s) (pine.buffer:scroll-top w))
                          (1- (pine.buffer:win-height w))))
              (pine.buffer:frame-cursor-col f)
              (- (pine.buffer:point-col s) (pine.buffer:col w))
              (pine.buffer:frame-scroll-pixel f)
              (coerce (pine.buffer:scroll-top w) 'double-float)))
      ;; modeline + echo/minibuffer (may move the cursor into the minibuffer)
      (setf off (render-chrome f off w))
      (setf (pine.buffer:frame-cell-count f) off
            (pine.buffer:frame-dirtyp f) t))))


;;;; The paint loop lives in the surface (pine.gtk pump), not here.


;;;; Subscription
;;;; Subscribers are identified by the client's renderer actor ref.
;;;; Buffers `tell` snapshots to the ref; unsubscribe matches by eq.

(defun subscribe-to-buffer (buffer-actor)
  (let ((renderer (pine.client:renderer (pine.client:current-client))))
    (when (and buffer-actor renderer)
      (sento.actor:tell buffer-actor
                        (list :subscribe :renderer renderer)))))

(defun unsubscribe-from-buffer (buffer-actor)
  (let ((renderer (pine.client:renderer (pine.client:current-client))))
    (when (and buffer-actor renderer)
      (sento.actor:tell buffer-actor
                        (list :unsubscribe :renderer renderer)))))
