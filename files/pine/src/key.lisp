(defpackage #:pine.key
  (:use #:cl)
  (:export #:key #:key-p #:make-key
           #:key-sym #:key-ctrl #:key-meta #:key-shift #:key-super
           #:key= #:parse-key #:key->string))

(in-package #:pine.key)

(defstruct (key (:constructor %make-key) (:copier nil))
  (sym   "" :type string  :read-only t)
  (ctrl  nil :type boolean :read-only t)
  (meta  nil :type boolean :read-only t)
  (shift nil :type boolean :read-only t)
  (super nil :type boolean :read-only t))

(defvar *cache* (make-hash-table :test 'equal))

(defun make-key (sym &key ctrl meta shift super)
  (let ((id (list sym ctrl meta shift super)))
    (or (gethash id *cache*)
        (setf (gethash id *cache*)
              (%make-key :sym sym :ctrl ctrl :meta meta :shift shift :super super)))))

(declaim (inline key=))
(defun key= (a b) (eq a b))

(defun parse-key (spec)
  (let ((ctrl nil) (meta nil) (shift nil) (super nil)
        (i 0) (n (length spec)))
    (loop while (and (< (1+ i) n) (char= (char spec (1+ i)) #\-)) do
      (case (char spec i)
        (#\C (setf ctrl t))
        (#\M (setf meta t))
        (#\S (setf shift t))
        (#\s (setf super t))
        (t (return)))
      (incf i 2))
    (make-key (subseq spec i) :ctrl ctrl :meta meta :shift shift :super super)))

(defun key->string (k)
  (with-output-to-string (s)
    (when (key-ctrl k)  (write-string "C-" s))
    (when (key-meta k)  (write-string "M-" s))
    (when (key-shift k) (write-string "S-" s))
    (when (key-super k) (write-string "s-" s))
    (write-string (key-sym k) s)))
