;;;; -*- Mode: Lisp; indent-tabs-mode: nil -*-

(in-package :pine.vt)

(cffi:define-foreign-library libpine-pty
  (t (:default "libpine-pty")))

(defvar *pty-loaded* nil)

(defun ensure-pty-lib ()
  (unless *pty-loaded*
    (handler-case
        (progn (cffi:load-foreign-library 'libpine-pty)
               (setf *pty-loaded* t))
      (error () nil)))
  *pty-loaded*)

(cffi:defcfun ("pine_pty_spawn" %pty-spawn) :int
  (command :string) (rows :int) (cols :int) (pid :pointer))

(cffi:defcfun ("pine_pty_set_size" pty-set-size) :void
  (fd :int) (rows :int) (cols :int))

(defun spawn-pty-process (command &key (rows 24) (cols 80))
  "Run COMMAND under /bin/sh in a new pty. Returns (values master-fd pid)."
  (ensure-pty-lib)
  (cffi:with-foreign-object (pid :int)
    (let ((master (%pty-spawn command rows cols pid)))
      (values master (cffi:mem-ref pid :int)))))

(defun pty-read-string (fd size)
  "Read up to SIZE bytes from FD as a string, or nil at EOF/error."
  (cffi:with-foreign-object (buf :unsigned-char size)
    (let ((n (cffi:foreign-funcall "read" :int fd :pointer buf :long size :long)))
      (when (plusp n)
        (cffi:foreign-string-to-lisp buf :count n :encoding :latin-1)))))

(defun pty-write-string (fd string)
  (cffi:with-foreign-string ((s len) string :encoding :utf-8)
    (cffi:foreign-funcall "write" :int fd :pointer s :long len :long)))

(defun pty-close (fd)
  (cffi:foreign-funcall "close" :int fd :int))
