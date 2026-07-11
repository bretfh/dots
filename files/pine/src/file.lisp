(in-package :pine.file)

(defun read-file (path)
  (with-open-file (s path :direction :input :if-does-not-exist nil)
    (when s
      (with-output-to-string (out)
        (loop for line = (read-line s nil nil)
              while line
              do (write-string line out)
                 (write-char #\Newline out))))))

(defun write-file (path text)
  (with-open-file (s path :direction :output
                          :if-exists :supersede
                          :if-does-not-exist :create)
    (write-string text s))
  path)

(defun find-file (path)
  (let* ((expanded (merge-pathnames path))
         (exists (probe-file expanded))
         (namestring (namestring expanded))
         (name (file-namestring expanded))
         (content (if exists (or (read-file expanded) "") "")))
    (when (string= name "") (setf name namestring))
    (let ((buf (pine.buffer:make-buffer name :content content)))
      (sento.actor:tell buf (list :set-local :key :pathname :value namestring))
      (sento.actor:tell buf (list :move-point :line 0 :col 0))
      (pine.buffer:switch-buffer name)
      (sento.actor:tell (pine.client:renderer (pine.client:current-client))
                        (list :switch-buffer :buffer buf :name name))
      (pine.render:subscribe-to-buffer buf)
      (let ((mode-kw (or (pine.mode:mode-for-file namestring) :text-mode)))
        (pine.mode:set-buffer-mode buf mode-kw))
      (pine.echo:message
              (if exists (format nil "~a" namestring)
                  (format nil "(new file) ~a" namestring)))
      buf)))

(defun save-current-buffer ()
  (let ((buf (pine.client:current-buffer (pine.client:current-client))))
    (when buf
      (let* ((state (sento.actor:ask-s buf '(:get-state) :time-out 5))
             (path (pine.buffer:buffer-local state :pathname))
             (text (pine.buffer:state->string state)))
        (if path
            (progn
              (write-file path text)
              (pine.echo:message (format nil "wrote ~a" path)))
            (pine.echo:message "no file path for this buffer"))))))
