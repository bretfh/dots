(in-package #:pine.var)

;;;; Editor variables. Three scopes resolved in order: buffer-local, then
;;;; global, then the definition default. Buffer-local values live in the
;;;; buffer's fset meta under :vars, so they ride along with buffer snapshots
;;;; for free. Definitions and global values are a registry (a special, like
;;;; the mode and command registries).

(defstruct (evar (:constructor %make-evar) (:copier nil))
  (name          nil :read-only t)
  (default       nil)
  (documentation "")
  (global        nil)
  (global-set    nil))

(defvar *variables* (make-hash-table :test 'eq))

(defun define-variable (name &key default documentation)
  (setf (gethash name *variables*)
        (%make-evar :name name :default default
                    :documentation (or documentation ""))))

(defun find-variable (name)
  (or (gethash name *variables*) (error "No editor variable ~s" name)))

(defun all-variable-names ()
  (sort (loop for k being the hash-keys of *variables* collect k) #'string<))

(defun %buffer-vars (buffer)
  (and buffer
       (let ((state (pine.buffer:ask buffer :state)))
         (and state (fset:@ (pine.buffer:meta state) :vars)))))

(defun %buffer-var (buffer name)
  "(values VALUE PRESENT-P) for NAME's buffer-local binding."
  (let ((vars (%buffer-vars buffer)))
    (if (and vars (fset:domain-contains? vars name))
        (values (fset:@ vars name) t)
        (values nil nil))))

(defun current-buffer* ()
  (let ((cli pine.client:*client*)) (and cli (pine.client:current-buffer cli))))

(defun variable-value (name &optional (buffer (current-buffer*)))
  "Resolve NAME: buffer-local, else global, else default."
  (let ((v (find-variable name)))
    (when buffer
      (multiple-value-bind (local present) (%buffer-var buffer name)
        (when present (return-from variable-value local))))
    (if (evar-global-set v) (evar-global v) (evar-default v))))

(defun variable-scope (name &optional (buffer (current-buffer*)))
  "Which scope NAME currently resolves through: :buffer, :global, or :default."
  (find-variable name)
  (cond ((and buffer (nth-value 1 (%buffer-var buffer name))) :buffer)
        ((evar-global-set (find-variable name)) :global)
        (t :default)))

(defun set-global (name value)
  (let ((v (find-variable name)))
    (setf (evar-global v) value (evar-global-set v) t)
    value))

(defun set-buffer-local (name value &optional (buffer (current-buffer*)))
  (find-variable name)
  (when buffer
    (pine.buffer:tell buffer :set-var :key name :value value))
  value)

(defun set-variable (name value &key buffer)
  "Set NAME buffer-locally when BUFFER is given, else globally."
  (if buffer (set-buffer-local name value buffer) (set-global name value)))
