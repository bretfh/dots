(in-package :pine.editor)

(defun completion ()
  (pine.client:completion-state (pine.client:current-client)))

(defun substring-match-p (input candidate)
  (search (string-downcase input) (string-downcase candidate)))

(defun filter-candidates (input candidates)
  (if (string= input "")
      candidates
      (remove-if-not (lambda (c) (substring-match-p input c)) candidates)))

(defun completing-read (prompt-text candidates cb)
  (let ((c (completion)))
    (setf (pine.client:active-p c) t
          (pine.client:candidates c) candidates
          (pine.client:input c) ""
          (pine.client:index c) (if candidates 0 -1)
          (pine.client:callback c) cb
          (pine.client:filtered c) (filter-candidates "" candidates)
          (pine.client:prompt c) prompt-text)
    (show-completions)
    (pine.echo:show-input prompt-text)))

(defun completion-accept ()
  (let* ((c (completion))
         (result (if (and (>= (pine.client:index c) 0)
                          (< (pine.client:index c) (length (pine.client:filtered c))))
                     (nth (pine.client:index c) (pine.client:filtered c))
                     (pine.client:input c)))
         (cb (pine.client:callback c)))
    (completion-cleanup)
    (when cb
      (handler-case (funcall cb result)
        (error (c)
          (pine.echo:message (format nil "error: ~a" c)))))))

(defun completion-cancel ()
  (completion-cleanup)
  (pine.echo:message "cancelled"))

(defun completion-cleanup ()
  (let ((c (completion)))
    (setf (pine.client:active-p c) nil
          (pine.client:candidates c) nil
          (pine.client:filtered c) nil
          (pine.client:index c) -1
          (pine.client:input c) ""
          (pine.client:callback c) nil
          (pine.client:dynamic-fn c) nil))
  (pine.echo:hide-completions-area)
  (pine.echo:hide-input))

(defun completion-next ()
  (let ((c (completion)))
    (when (pine.client:filtered c)
      (setf (pine.client:index c)
            (min (1+ (pine.client:index c)) (1- (length (pine.client:filtered c)))))
      (show-completions))))

(defun completion-prev ()
  (let ((c (completion)))
    (when (pine.client:filtered c)
      (setf (pine.client:index c) (max 0 (1- (pine.client:index c))))
      (show-completions))))

(defun completion-update-input (text)
  (let* ((c (completion))
         (cands (if (pine.client:dynamic-fn c)
                    (funcall (pine.client:dynamic-fn c) text)
                    (filter-candidates text (pine.client:candidates c)))))
    (setf (pine.client:input c) text
          (pine.client:filtered c) cands
          (pine.client:index c) (if cands 0 -1))
    (show-completions)))

(defun show-completions ()
  (let* ((c (completion))
         (max-visible 12)
         (filtered (pine.client:filtered c))
         (n (length filtered))
         (idx (pine.client:index c))
         (visible (subseq filtered 0 (min max-visible n)))
         (lines (loop for cand in visible
                      for i from 0
                      collect (if (= i idx)
                                  (format nil "> ~a" cand)
                                  (format nil "  ~a" cand)))))
    (if lines
        (pine.echo:show-completions-area
         (format nil "~{~a~^~%~}" lines))
        (pine.echo:show-completions-area "(no matches)"))))

(defun completing-read-active-p ()
  (let ((cli pine.client:*client*))
    (and cli (pine.client:active-p (pine.client:completion-state cli)))))

(defun file-completion-active-p ()
  (and (completing-read-active-p)
       (pine.client:dynamic-fn (completion))))


;;;; Filesystem path completion (find-file)

(defun expand-tilde (text)
  (cond
    ((string= text "~") (namestring (user-homedir-pathname)))
    ((and (>= (length text) 2) (string= (subseq text 0 2) "~/"))
     (concatenate 'string (namestring (user-homedir-pathname)) (subseq text 2)))
    (t text)))

(defun split-path (path)
  "Directory part (through the last slash) and the trailing basename."
  (let ((slash (position #\/ path :from-end t)))
    (if slash
        (values (subseq path 0 (1+ slash)) (subseq path (1+ slash)))
        (values "" path))))

(defun directory-entries (dir)
  "Names in DIR: subdirectories with a trailing slash, then files. nil if DIR
cannot be read."
  (handler-case
      (append
       (sort (mapcar (lambda (p)
                       (concatenate 'string (car (last (pathname-directory p))) "/"))
                     (uiop:subdirectories dir))
             #'string<)
       (sort (mapcar #'file-namestring (uiop:directory-files dir)) #'string<))
    (error () nil)))

(defun file-name-completions (text)
  "Directory entries matching the basename the user is typing."
  (multiple-value-bind (dir base) (split-path (expand-tilde text))
    (let ((entries (directory-entries (if (string= dir "") "./" dir))))
      (if (string= base "")
          entries
          (remove-if-not
           (lambda (n) (and (>= (length n) (length base))
                            (string= base (subseq n 0 (length base)))))
           entries)))))

(defun longest-common-prefix (strings)
  (if (null strings)
      ""
      (let ((p (first strings)))
        (dolist (s (rest strings) p)
          (let ((n (min (length p) (length s))))
            (setf p (subseq p 0 (or (mismatch p s :end1 n :end2 n) n))))))))

(defun default-directory ()
  (let* ((buf (cur-buffer))
         (path (and buf (ignore-errors
                          (pine.buffer:buffer-local
                           (pine.buffer:ask buf :state) :pathname nil)))))
    (if path (directory-namestring path) (namestring (uiop:getcwd)))))

(defun read-file-name (prompt-text cb)
  (let ((c (completion)) (initial (default-directory)))
    (setf (pine.client:active-p c) t
          (pine.client:candidates c) nil
          (pine.client:dynamic-fn c) #'file-name-completions
          (pine.client:callback c) cb
          (pine.client:prompt c) prompt-text)
    (pine.echo:show-input prompt-text)
    (pine.echo:set-input-text initial)
    (completion-update-input initial)))

(defun file-name-complete ()
  "Tab: extend the path by the entries' common prefix; a lone match completes
fully (directories keep their trailing slash so the next Tab descends)."
  (let ((cands (pine.client:filtered (completion))))
    (multiple-value-bind (dir base) (split-path (expand-tilde (pine.client:input (completion))))
      (declare (ignore base))
      (when cands
        (let ((add (if (= 1 (length cands)) (first cands) (longest-common-prefix cands))))
          (minibuffer-set-text (concatenate 'string dir add)))))))

(defun file-name-accept ()
  "Return: a highlighted entry (when the typed path is not itself a file) is
taken; a directory is descended into, a file is opened."
  (let* ((c (completion))
         (typed (expand-tilde (pine.client:input c)))
         (sel (let ((i (pine.client:index c)) (f (pine.client:filtered c)))
                (when (and (>= i 0) (< i (length f))) (nth i f))))
         (target (multiple-value-bind (dir base) (split-path typed)
                   (declare (ignore base))
                   (if (and sel (not (uiop:file-exists-p typed))
                            (not (uiop:directory-exists-p typed)))
                       (concatenate 'string dir sel)
                       typed))))
    (if (uiop:directory-exists-p target)
        (minibuffer-set-text (if (and (plusp (length target))
                                      (char= (char target (1- (length target))) #\/))
                                 target
                                 (concatenate 'string target "/")))
        (let ((cb (pine.client:callback c)))
          (completion-cleanup)
          (when cb (funcall cb target))))))
