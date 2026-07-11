(in-package :pine)

(defvar *version* "0.0.1")

(defvar *target*
  #+darwin :macos
  #+linux :linux
  #+windows :windows
  #-(or darwin linux windows) :linux)

(defun desktop? ()
  (member *target* '(:linux :macos :windows)))

(defun mobile? ()
  (member *target* '(:android :ios)))

(defun main (&key (workers 4) (remoting-port 0))
  (format t "pine ~a on ~a ~a [~a]~%"
          *version*
          (lisp-implementation-type)
          (lisp-implementation-version)
          *target*)
  (let ((srv (pine.server:start-server :workers workers
                                       :remoting-port remoting-port)))
    (setf (pine.server:ts-runtime srv) (pine.ts:make-ts-runtime))
    (pine.event:make-event-bus srv)
    (pine.actor:start-agent-registry srv)
    (pine.actor:start-local-agent srv)
    (let ((cli (pine.client:start-client srv)))
      (setf pine.client:*client* cli)
      (pine.buffer:install-default-faces)
      (pine.editor:start-editor)
      (pine.hooks:run-init-hooks)
      
      (format t "pine ready [port ~a]~%"
              (or (pine.server:remoting-port srv) "none"))
      (values srv cli))))

(defun stop ()
  (pine.hooks:run-shutdown-hooks))

(defun on-minibuffer-accept (text)
  (pine.editor:on-minibuffer-accept text))
