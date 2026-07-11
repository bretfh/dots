(defpackage #:pine.command
  (:use #:cl)
  (:export #:command #:command-name #:command-fn #:command-arguments #:command-prefix-p
           #:define-command #:register-command #:find-command #:all-command-names
           #:execute #:call-command #:dispatch #:self-insert #:self-insert-key-p
           #:prefix-numeric-value #:this-command-key
           #:key-binding #:read-next-key
           #:*minibuffer-handler* #:*terminal-handler*))

(in-package #:pine.command)

(defvar *minibuffer-handler* nil)
(defvar *terminal-handler* nil)

(defclass command ()
  ((name      :initarg :name      :reader command-name)
   (fn        :initarg :fn        :reader command-fn)
   ;; interactive spec: a list of argument descriptors gathered before the fn
   ;; runs (:universal :number :region ...). nil = a 0-arg command.
   (arguments :initarg :arguments :reader command-arguments :initform nil)
   ;; prefix commands (C-u, digit-argument) set the prefix arg instead of
   ;; consuming it, so dispatch must not clear it after they run.
   (prefix-p  :initarg :prefix-p  :reader command-prefix-p  :initform nil)))

(defvar *commands* (make-hash-table :test 'equal))

(defun register-command (command)
  (setf (gethash (command-name command) *commands*) command))

(defun find-command (name)
  (etypecase name
    (command name)
    (string  (gethash name *commands*))))

(defun all-command-names ()
  (sort (loop for k being the hash-keys of *commands* collect k) #'string<))

(defmacro define-command (name (&rest lambda-list) &body body)
  "Define and register a command. An optional interactive spec may lead the
body as (:interactive DESCRIPTOR...) or (:prefix); the descriptors gather the
LAMBDA-LIST arguments before the body runs."
  (let ((arguments nil) (prefix-p nil))
    (loop while (and (consp (first body)) (keywordp (car (first body))))
          for clause = (pop body)
          do (case (car clause)
               (:interactive (setf arguments (cdr clause)))
               (:prefix      (setf prefix-p t))
               (t (push clause body) (loop-finish))))
    `(register-command
      (make-instance 'command :name ,name
                     :arguments ',arguments :prefix-p ,prefix-p
                     :fn (lambda ,lambda-list ,@body)))))

;;;; Prefix argument (C-u / digit-argument). Stored raw on the client:
;;;; nil = none, an integer = explicit, (4) = one bare C-u, (16) = C-u C-u.

(defun prefix-numeric-value (arg &optional (default 1))
  "The numeric value of a raw prefix ARG (Emacs prefix-numeric-value)."
  (cond ((null arg) default)
        ((integerp arg) arg)
        ((consp arg) (car arg))
        ((eq arg '-) -1)
        (t default)))

(defun this-command-key (client) (pine.client:this-command-key client))

(defun %region-bounds (client)
  "Region as (start-line start-col end-line end-col) from mark and point,
normalized so start precedes end. nil if no mark."
  (let ((buf (pine.client:current-buffer client)))
    (when buf
      (multiple-value-bind (sl sc el ec)
          (pine.editor:region-bounds (pine.buffer:ask buf :state))
        (and sl (list sl sc el ec))))))

(defun gather-arguments (command client argument)
  "Turn COMMAND's interactive descriptors into the actual argument list,
using the raw prefix ARGUMENT and current client state."
  (loop for d in (command-arguments command)
        append (ecase d
                 (:universal (list argument))
                 (:number    (list (prefix-numeric-value argument)))
                 (:region    (or (%region-bounds client) (list nil nil nil nil))))))

(defgeneric execute (modes command argument)
  (:documentation "Run COMMAND. MODES is the active-modes instance so modes can
layer :before/:after/:around methods. ARGUMENT is the raw prefix argument.")
  (:method (modes command argument)
    (declare (ignore modes))
    (apply (command-fn command)
           (gather-arguments command (pine.client:current-client) argument))))

(defun call-command (name-or-command)
  (let ((cmd (find-command name-or-command))
        (client (pine.client:current-client)))
    (when cmd
      (let ((arg (pine.client:prefix-arg client)))
        (handler-case
            (execute (pine.mode:active-modes-instance client) cmd arg)
          (error (c) (pine.echo:message (format nil "error: ~a" c))))
        (setf (pine.client:last-command client) (command-name cmd))
        (unless (command-prefix-p cmd)
          (setf (pine.client:prefix-arg client) nil))))))

(defun self-insert-key-p (key)
  "True when KEY should insert its own character (printable, no C-/M-/super)."
  (and (= 1 (length (pine.key:key-sym key)))
       (not (pine.key:key-ctrl key))
       (not (pine.key:key-meta key))
       (not (pine.key:key-super key))))

(defun self-insert (client key)
  (when (and key (self-insert-key-p key))
    (let ((buf (pine.client:current-buffer client)))
      (when buf
        (let ((n (prefix-numeric-value (pine.client:prefix-arg client))))
          (dotimes (i (max 1 n))
            (pine.buffer:tell buf :insert :text (pine.key:key-sym key))))))))

(register-command
 (make-instance 'command :name "self-insert-command"
                :fn (lambda ()
                      (let ((client (pine.client:current-client)))
                        (self-insert client (pine.client:this-command-key client))))))

(defun %resolve (client key)
  (loop for km in (pine.mode:active-keymaps client)
        for entry = (pine.keymap:keymap-lookup km key)
        when entry return entry))

(defun key-binding (client key)
  "KEY's binding in CLIENT's active keymaps: a command name string, a prefix
sub-keymap, or nil."
  (%resolve client key))

(defun read-next-key (client fn)
  "Capture the next dispatched key and hand it to FN instead of running its
binding. One-shot. The basis for describe-key, quoted-insert, etc."
  (setf (pine.client:pending-key-reader client) fn))

(defun dispatch (client key)
  "Feed one pine.key:key: resolve via the pending prefix or the active keymaps."
  (setf (pine.client:this-command-key client) key)
  (let ((reader (pine.client:pending-key-reader client)))
    (when reader
      (setf (pine.client:pending-key-reader client) nil)
      (return-from dispatch (funcall reader key))))
  (when (and *minibuffer-handler* (funcall *minibuffer-handler* client key))
    (return-from dispatch))
  ;; in a terminal, keys go to the pty — unless a prefix (C-x ...) is pending.
  (when (and *terminal-handler* (null (pine.client:pending-keys client))
             (funcall *terminal-handler* client key))
    (return-from dispatch))
  (handler-case
      (let* ((pending (pine.client:pending-keys client))
             (entry (if pending
                        (gethash key pending)
                        (%resolve client key))))
        (cond
          ((pine.keymap:prefix-p entry)
           (setf (pine.client:pending-keys client) entry))
          (entry
           (setf (pine.client:pending-keys client) nil)
           (call-command entry))
          (t
           (setf (pine.client:pending-keys client) nil)
           (if (self-insert-key-p key)
               (call-command "self-insert-command")
               ;; an unbound non-self-inserting key still terminates a prefix arg
               (setf (pine.client:prefix-arg client) nil)))))
    (error (c)
      (setf (pine.client:pending-keys client) nil)
      (pine.echo:message (format nil "error: ~a" c)))))
