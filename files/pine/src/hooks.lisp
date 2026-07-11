(in-package :pine.hooks)

(defvar *init-hooks* nil)
(defvar *shutdown-hooks* nil)

(defun add-init-hook (name fn)
  (setf *init-hooks*
        (append (remove name *init-hooks* :key #'first) (list (cons name fn)))))

(defun add-shutdown-hook (name fn)
  (setf *shutdown-hooks*
        (append (remove name *shutdown-hooks* :key #'first) (list (cons name fn)))))

(defun run-init-hooks ()
  (loop for (name . fn) in *init-hooks*
        do (handler-case (funcall fn)
             (error (c)
               (format *error-output* "init hook ~a failed: ~a~%" name c)))))

(defun run-shutdown-hooks ()
  (loop for (name . fn) in (reverse *shutdown-hooks*)
        do (handler-case (funcall fn)
             (error (c)
               (format *error-output* "shutdown hook ~a failed: ~a~%" name c)))))
