;; -*- lexical-binding: t -*-

(add-to-list 'default-frame-alist '(font . "Fira Code 18"))

;;(use-package exec-path-from-shell)
(use-package exec-path-from-shell
  :config
  (exec-path-from-shell-initialize))

(setq dired-use-ls-dired t
      insert-directory-program "/opt/homebrew/bin/gls")

(global-set-key [(hyper a)] 'mark-whole-buffer)
(global-set-key [(hyper v)] 'yank)
(global-set-key [(hyper c)] 'kill-ring-save)
(global-set-key [(hyper s)] 'save-buffer)
(global-set-key [(hyper l)] 'goto-line)
(global-set-key [(hyper w)]
                (lambda () (interactive) (delete-window)))
(global-set-key [(hyper z)] 'undo)

(defun mac-switch-meta nil 
  "switch meta between Option and Command"
  (interactive)
  (if (eq mac-option-modifier nil)
      (progn
	(setq mac-option-modifier 'meta)
	(setq mac-command-modifier 'hyper))
    (progn 
      (setq mac-option-modifier nil)
      (setq mac-command-modifier 'meta))))

(provide 'rez-macos)
