(in-package #:pine.echo)

(defvar *message* "")
(defvar *input-prompt* nil)
(defvar *input-text* "")
(defvar *completions* nil)

(defun message (text)
  (setf *message* (or text ""))
  nil)

(defun current-message () *message*)

(defun show-input (prompt)
  (setf *input-prompt* (or prompt "")
        *input-text* ""
        *message* "")
  nil)

(defun hide-input ()
  (setf *input-prompt* nil
        *input-text* ""
        *completions* nil)
  nil)

(defun input-active-p () (and *input-prompt* t))
(defun input-prompt () *input-prompt*)
(defun input-text () *input-text*)
(defun set-input-text (text) (setf *input-text* (or text "")) nil)

(defun show-completions-area (text) (setf *completions* text) nil)
(defun hide-completions-area () (setf *completions* nil) nil)
(defun completions-text () *completions*)
