;; -*- lexical-binding: t -*-

(defun vex/set-gnome-bg ()
  (interactive)
  (let ((files '("*.png" "*.jpg"))
	(result))
    (dolist (elt files result)
      (setq result (cons (mapcar #'file-truename (file-expand-wildcards (concat "~/Downloads/" elt))) result)))
    ((lambda (path)
      (shell-command
       (format "gsettings set org.gnome.desktop.background picture-uri file:///%s"
	       (completing-read "Choose one: " (flatten-list path)))))
     result)))

(provide rez-fns)
