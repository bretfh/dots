(defpackage #:pine.keymap
  (:use #:cl)
  (:export #:keymap #:keymap-p #:make-keymap #:keymap-name #:keymap-parent
           #:define-key #:keymap-lookup #:prefix-p #:keymap-bindings))

(in-package #:pine.keymap)

(defstruct (keymap (:constructor %make-keymap) (:copier nil))
  (name nil)
  (parent nil)
  (table (make-hash-table :test 'eq) :read-only t))

(defun make-keymap (&key name parent) (%make-keymap :name name :parent parent))

(declaim (inline prefix-p))
(defun prefix-p (entry) (hash-table-p entry))

(defun define-key (keymap keys command)
  "KEYS is a pine.key:key or a list of them (a chord). COMMAND is a string name."
  (let ((table (keymap-table keymap))
        (keys (if (listp keys) keys (list keys))))
    (loop for (k . rest) on keys do
      (if rest
          (let ((next (gethash k table)))
            (unless (hash-table-p next)
              (setf next (make-hash-table :test 'eq)
                    (gethash k table) next))
            (setf table next))
          (setf (gethash k table) command)))
    command))

(defun keymap-lookup (keymap key)
  "Command name, prefix sub-table, or nil. Local bindings shadow the parent."
  (or (gethash key (keymap-table keymap))
      (let ((p (keymap-parent keymap)))
        (and p (keymap-lookup p key)))))

(defun keymap-bindings (keymap &optional include-parent)
  "List of (KEY-STRING . COMMAND) in KEYMAP. Chords render space-joined. With
INCLUDE-PARENT, unshadowed parent bindings are appended."
  (let ((acc '()))
    (labels ((walk (table prefix)
               (maphash
                (lambda (k v)
                  (let ((seq (if prefix
                                 (concatenate 'string prefix " " (pine.key:key->string k))
                                 (pine.key:key->string k))))
                    (if (hash-table-p v)
                        (walk v seq)
                        (push (cons seq v) acc))))
                table)))
      (walk (keymap-table keymap) nil))
    (when (and include-parent (keymap-parent keymap))
      (let ((local (mapcar #'car acc)))
        (dolist (pb (keymap-bindings (keymap-parent keymap) t))
          (unless (member (car pb) local :test #'string=)
            (push pb acc)))))
    acc))
