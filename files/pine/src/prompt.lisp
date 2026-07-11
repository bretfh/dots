(in-package :pine.editor)

(defun prompt (prompt-text cb)
  (let ((client (pine.client:current-client)))
    (setf (pine.client:prompt-callback client) cb
          (pine.client:prompt-active client) t))
  (pine.echo:show-input prompt-text))

(defun minibuffer-active-p () (pine.echo:input-active-p))

(defun minibuffer-text ()
  (if (completing-read-active-p)
      (pine.client:input (completion))
      (pine.echo:input-text)))

(defun minibuffer-set-text (text)
  (pine.echo:set-input-text text)
  (when (completing-read-active-p)
    (completion-update-input text)))

(defun minibuffer-handle-key (key)
  (let ((sym (pine.key:key-sym key)))
    (cond
      ((or (string= sym "Escape")
           (and (pine.key:key-ctrl key) (string= sym "g")))
       (cancel-prompt))
      ((string= sym "Return")
       (if (file-completion-active-p)
           (file-name-accept)
           (on-minibuffer-accept (minibuffer-text))))
      ((string= sym "BackSpace")
       (let ((s (minibuffer-text)))
         (minibuffer-set-text (if (plusp (length s)) (subseq s 0 (1- (length s))) s))))
      ((and (completing-read-active-p) (string= sym "Tab"))
       (if (file-completion-active-p) (file-name-complete) (completion-next)))
      ((and (completing-read-active-p)
            (or (string= sym "Down")
                (and (pine.key:key-ctrl key) (string= sym "n"))))
       (completion-next))
      ((and (completing-read-active-p)
            (or (string= sym "Up")
                (and (pine.key:key-ctrl key) (string= sym "p"))))
       (completion-prev))
      ((pine.command:self-insert-key-p key)
       (minibuffer-set-text (concatenate 'string (minibuffer-text) sym))))))

(defun minibuffer-dispatch (client key)
  (declare (ignore client))
  (when (minibuffer-active-p)
    (minibuffer-handle-key key)
    t))

(defun cancel-prompt ()
  (let ((client pine.client:*client*))
    (cond
      ((and client (completing-read-active-p))
       (completion-cancel))
      ((and client (pine.client:prompt-active client))
       (setf (pine.client:prompt-active client) nil
             (pine.client:prompt-callback client) nil)
       (pine.echo:hide-input)
       (pine.echo:message "cancelled")))))

(defun on-minibuffer-accept (text)
  (let ((client (pine.client:current-client)))
    (cond
      ((completing-read-active-p)
       (completion-update-input text)
       (completion-accept))
      ((pine.client:prompt-active client)
       (let ((cb (pine.client:prompt-callback client)))
         (setf (pine.client:prompt-active client) nil
               (pine.client:prompt-callback client) nil)
         (pine.echo:hide-input)
         (when cb
           (handler-case (funcall cb text)
             (error (c)
               (pine.echo:message
                       (format nil "error: ~a" c)))))))
      (t
       (handler-case
           (let ((result (eval (read-from-string text))))
             (pine.echo:hide-input)
             (pine.echo:message (format nil "=> ~s" result)))
         (error (c)
           (pine.echo:hide-input)
           (pine.echo:message (format nil "error: ~a" c))))))))
