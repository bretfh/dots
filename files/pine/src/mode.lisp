(in-package #:pine.mode)

;;;; Mode classes. Modes are CLOS classes; the active modes of a buffer are
;;;; composed into one dispatch class (MOP) so command execution and behavior
;;;; layer minor -> major via method combination.

(defclass mode ()
  ((name      :initarg :name      :reader mode-name      :initform nil)
   (keymap    :initarg :keymap    :reader mode-keymap    :initform nil)
   (indicator :initarg :indicator :reader mode-indicator :initform "")))

(defclass major-mode (mode)
  ((parent-mode :initarg :parent-mode :reader parent-mode :initform nil)
   (ts-language :initarg :ts-language :reader ts-language  :initform nil)))

(defclass minor-mode (mode)
  ((precedence  :initarg :precedence  :reader precedence  :initform 0)
   (transparent :initarg :transparent :reader transparent :initform nil)))

(defclass base-mode (major-mode) ())
(defclass text-mode (base-mode) ())
(defclass lisp-mode (text-mode) ())
(defclass repl-mode (text-mode) ())
(defclass terminal-mode (base-mode) ())

(defclass overwrite-mode (minor-mode) ())

;;;; Registry (singletons keyed by keyword name) + global keymap

(defvar *modes* (make-hash-table :test 'eq))
(defvar *global-keymap* nil)

(defun register-mode (m) (setf (gethash (mode-name m) *modes*) m))
(defun find-mode (name) (gethash name *modes*))
(defun global-keymap () *global-keymap*)

;;;; Buffer association

(defun buffer-mode (buffer-or-snap)
  (let ((name (pine.buffer:buffer-local buffer-or-snap :mode :base-mode)))
    (or (find-mode name) (find-mode :base-mode))))

(defun current-buffer-mode ()
  (let* ((client (pine.client:current-client))
         (buf (pine.client:current-buffer client))
         (name (and buf (gethash buf (pine.client:buffer-modes client)))))
    (or (and name (find-mode name)) (find-mode :base-mode))))

(defun set-buffer-mode (buffer-actor mode-name)
  (unless (find-mode mode-name) (error "No mode named ~s" mode-name))
  (setf (gethash buffer-actor (pine.client:buffer-modes (pine.client:current-client)))
        mode-name)
  (sento.actor:tell buffer-actor (list :set-local :key :mode :value mode-name))
  (find-mode mode-name))

(defun mode-for-file (path)
  (let ((ext (pathname-type (pathname path))))
    (cond ((null ext) nil)
          ((member ext '("lisp" "cl" "asd" "asdf" "lsp") :test #'string-equal)
           :lisp-mode)
          (t nil))))

;;;; Minor modes. Per-buffer, precedence-numbered (higher = more specific).
;;;; The enabled set feeds both the active-keymap list and the synthesized
;;;; dispatch class, so a minor mode augments via keymap bindings and via
;;;; execute method combination (:before/:after transparent, :around opaque).

(defun %minor-names (client)
  (gethash (pine.client:current-buffer client)
           (pine.client:buffer-minor-modes client)))

(defun (setf %minor-names) (names client)
  (setf (gethash (pine.client:current-buffer client)
                 (pine.client:buffer-minor-modes client))
        names))

(defun buffer-minor-modes (client)
  "Active minor-mode singletons for the current buffer, most specific first."
  (stable-sort
   (loop for name in (%minor-names client)
         for m = (find-mode name)
         when (typep m 'minor-mode) collect m)
   #'> :key #'precedence))

(defun minor-mode-enabled-p (client name)
  (and (member name (%minor-names client)) t))

(defun enable-minor-mode (client name)
  (unless (typep (find-mode name) 'minor-mode)
    (error "~s is not a minor mode" name))
  (pushnew name (%minor-names client))
  t)

(defun disable-minor-mode (client name)
  (setf (%minor-names client) (remove name (%minor-names client)))
  nil)

(defun toggle-minor-mode (client name)
  (if (minor-mode-enabled-p client name)
      (disable-minor-mode client name)
      (enable-minor-mode client name)))

(defun active-minor-mode-indicators (client)
  (loop for m in (buffer-minor-modes client) collect (mode-indicator m)))

;;;; Active modes -> keymaps + a synthesized dispatch class

(defun buffer-active-modes (client)
  "Minor modes (most specific first) then the major mode. This is the
superclass order of the synthesized dispatch class, so minor-mode methods
run before the major mode's under CLOS method combination."
  (append (buffer-minor-modes client) (list (current-buffer-mode))))

(defun active-keymaps (client)
  (append (mapcar #'mode-keymap (buffer-minor-modes client))
          (list (mode-keymap (current-buffer-mode)) *global-keymap*)))

(defvar *dispatch-classes* (make-hash-table :test 'equal))

(defun modes-dispatch-class (classes)
  (let ((key (mapcar #'class-name classes)))
    (or (gethash key *dispatch-classes*)
        (setf (gethash key *dispatch-classes*)
              (c2mop:ensure-class (gensym "PINE-MODES")
                                  :direct-superclasses classes)))))

(defun active-modes-instance (client)
  (make-instance (modes-dispatch-class
                  (mapcar #'class-of (buffer-active-modes client)))))

;;;; Buffer behavior. The buffer actor's receive calls
;;;; (dispatch-message MODE SELF TAG PLIST). base-mode has the infrastructure
;;;; verbs; text-mode layers editing; subclasses override.

(defgeneric dispatch-message (mode self tag plist))

(defmethod dispatch-message ((mode base-mode) self tag plist)
  (declare (ignore self))
  (destructuring-bind (state undo redo subs hl) sento.actor:*state*
    (case tag
      (:get-state (sento.actor:reply state))
      (:get-snapshot (sento.actor:reply (pine.buffer:state->snapshot state)))
      (:get-text (sento.actor:reply (pine.buffer:state->string state)))
      (:get-local
       (sento.actor:reply
        (pine.buffer:buffer-local state (getf plist :key) (getf plist :default))))
      (:subscribe
       (let ((r (getf plist :renderer)))
         (setf sento.actor:*state* (list state undo redo (adjoin r subs :test #'eq) hl))
         (sento.actor:tell r
           (list :snapshot :snapshot (pine.buffer:state->snapshot-with-hl state hl)))))
      (:unsubscribe
       (let ((r (getf plist :renderer)))
         (setf sento.actor:*state* (list state undo redo (remove r subs :test #'eq) hl))))
      (:highlights
       (let ((h (getf plist :highlights)))
         (setf sento.actor:*state* (list state undo redo subs h))
         (pine.buffer:notify-subscribers subs state h)))
      (:undo
       (when undo
         (let ((prev (first undo)))
           (setf sento.actor:*state* (list prev (rest undo) (cons state redo) subs hl))
           (pine.buffer:notify-subscribers subs prev hl))))
      (:redo
       (when redo
         (let ((next (first redo)))
           (setf sento.actor:*state* (list next (cons state undo) (rest redo) subs hl))
           (pine.buffer:notify-subscribers subs next hl))))
      ((:set-local :set-meta)
       (let ((new (pine.buffer:set-meta state (getf plist :key) (getf plist :value))))
         (setf sento.actor:*state* (list new undo redo subs hl))
         (pine.buffer:notify-subscribers subs new hl)))
      (:set-var
       (let* ((vars (or (fset:@ (pine.buffer:meta state) :vars) (fset:empty-map)))
              (new (pine.buffer:set-meta
                    state :vars (fset:with vars (getf plist :key) (getf plist :value)))))
         (setf sento.actor:*state* (list new undo redo subs hl))
         (pine.buffer:notify-subscribers subs new hl)))
      (:replace-content
       (let ((new (pine.buffer:set-meta
                   (pine.buffer:load-content (getf plist :content))
                   :name (or (fset:@ (pine.buffer:meta state) :name) ""))))
         ;; fresh content clears history
         (setf sento.actor:*state* (list new nil nil subs hl))
         (pine.buffer:notify-subscribers subs new hl))))))

(defmethod dispatch-message ((mode text-mode) self tag plist)
  (destructuring-bind (state undo redo subs hl) sento.actor:*state*
    ;; edits push the old state onto UNDO and clear REDO.
    (macrolet ((commit (new-state)
                 `(let ((new ,new-state))
                    (setf sento.actor:*state* (list new (cons state undo) nil subs hl))
                    (pine.buffer:notify-subscribers subs new hl))))
      (case tag
        (:insert
         (let* ((snap (pine.buffer:state->snapshot state))
                (l (pine.buffer:point-line snap))
                (c (pine.buffer:point-col snap)))
           (commit (pine.buffer:insert-string state l c (getf plist :text)))))
        (:newline
         (let* ((snap (pine.buffer:state->snapshot state))
                (l (pine.buffer:point-line snap))
                (c (pine.buffer:point-col snap)))
           (commit (pine.buffer:insert-newline state l c))))
        (:backspace
         (let* ((snap (pine.buffer:state->snapshot state))
                (l (pine.buffer:point-line snap))
                (c (pine.buffer:point-col snap)))
           (cond
             ((plusp c)
              (commit (pine.buffer:move-mark
                       (pine.buffer:delete-char state l (1- c)) :point l (1- c))))
             ((plusp l)
              (let ((prev-len (length (fset:@ (pine.buffer:lines state) (1- l)))))
                (commit (pine.buffer:move-mark
                         (pine.buffer:delete-char state (1- l) prev-len)
                         :point (1- l) prev-len)))))))
        (:move-point
         (let ((new (pine.buffer:move-mark state :point
                                           (getf plist :line) (getf plist :col))))
           (setf sento.actor:*state* (list new undo redo subs hl))
           (pine.buffer:notify-subscribers subs new hl)))
        (:delete-region
         (commit (pine.buffer:delete-region state
                                            (getf plist :start-line) (getf plist :start-col)
                                            (getf plist :end-line) (getf plist :end-col))))
        (:append-with-prompt
         (let* ((text (getf plist :text)) (pr (getf plist :prompt))
                (snap (pine.buffer:state->snapshot state))
                (last-line (1- (pine.buffer:line-count snap)))
                (last-col (length (fset:@ (pine.buffer:lines state) last-line)))
                (s1 (pine.buffer:move-mark state :point last-line last-col))
                (s2 (pine.buffer:insert-newline s1 last-line last-col))
                (s3 (pine.buffer:insert-string s2 (1+ last-line) 0 text))
                (s4-snap (pine.buffer:state->snapshot s3))
                (s4-line (1- (pine.buffer:line-count s4-snap)))
                (s4-col (length (fset:@ (pine.buffer:lines s3) s4-line)))
                (s5 (pine.buffer:insert-newline s3 s4-line s4-col)))
           (commit (pine.buffer:insert-string s5 (1+ s4-line) 0 pr))))
        (t (call-next-method))))))

(defmethod dispatch-message ((mode repl-mode) self tag plist)
  (declare (ignore self plist))
  (case tag
    (:newline (pine.repl:repl-submit))
    (t (call-next-method))))

(defmethod dispatch-message ((mode terminal-mode) self tag plist)
  (case tag
    (:insert (pine.term:term-write self (getf plist :text)))
    (:newline (pine.term:term-write self (string #\Newline)))
    (:backspace (pine.term:term-write self (string (code-char 127))))
    (:get-text
     (let ((term (pine.term:terminal-for-buffer self)))
       (sento.actor:reply (if term (pine.term:gterm-text term) ""))))
    ((:move-point :delete-region :undo :redo :replace-content :append-with-prompt) nil)
    (t (call-next-method))))

;;;; Defaults

(defun install-default-modes ()
  (setf *global-keymap* (pine.keymap:make-keymap :name :global))
  (let* ((base (register-mode
                (make-instance 'base-mode :name :base-mode :indicator "BASE"
                               :keymap (pine.keymap:make-keymap :name :base))))
         (text (register-mode
                (make-instance 'text-mode :name :text-mode :parent-mode base
                               :indicator "TEXT"
                               :keymap (pine.keymap:make-keymap
                                        :name :text :parent (mode-keymap base))))))
    (register-mode (make-instance 'lisp-mode :name :lisp-mode :parent-mode text
                                  :ts-language :commonlisp :indicator "LISP"
                                  :keymap (pine.keymap:make-keymap
                                           :name :lisp :parent (mode-keymap text))))
    (register-mode (make-instance 'repl-mode :name :repl-mode :parent-mode text
                                  :indicator "REPL"
                                  :keymap (pine.keymap:make-keymap
                                           :name :repl :parent (mode-keymap text))))
    (register-mode (make-instance 'terminal-mode :name :terminal-mode :parent-mode base
                                  :indicator "TERM"
                                  :keymap (pine.keymap:make-keymap
                                           :name :term :parent (mode-keymap base))))
    (register-mode (make-instance 'overwrite-mode :name :overwrite-mode
                                  :precedence 10 :transparent t :indicator "Ovwrt"
                                  :keymap (pine.keymap:make-keymap :name :overwrite)))
    base))

;;;; overwrite-mode: transparent augmentation of self-insert. It runs BEFORE
;;;; the base insert (method combination), deleting the char under point so the
;;;; inserted char overwrites it, then falls through to the normal insert.

(defun %overwrite-forward ()
  (let ((buf (pine.client:current-buffer (pine.client:current-client))))
    (when buf
      (multiple-value-bind (l c) (pine.buffer:ask buf :point)
        (let ((line (pine.buffer:ask buf :line l)))
          (when (and line (< c (length line)))
            (pine.buffer:tell buf :delete-region
                              :start-line l :start-col c
                              :end-line l :end-col (1+ c))))))))

(defmethod pine.command:execute :before ((modes overwrite-mode) command argument)
  (declare (ignore argument))
  (when (string= (pine.command:command-name command) "self-insert-command")
    (%overwrite-forward)))
