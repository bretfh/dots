(use-package shelldon
;;  :bind ("C-c t" . )
  :config
  (setf shell-command-switch "-ic")
  (setf enable-recursive-minibuffers t)
  (add-hook 'shelldon-mode-hook 'ansi-color-for-comint-mode-on)
  (add-to-list 'comint-output-filter-functions 'ansi-color-process-output)
  (autoload 'ansi-color-for-comint-mode-on "ansi-color" nil t)
  (add-to-list 'display-buffer-alist
	       '("*shelldon:"
		 (display-buffer-reuse-window display-buffer-in-previous-window display-buffer-in-side-window display-buffer-pop-up-window)
		 (side . right)
		 (slot . 0)
		 (window-width . 80))))

(use-package bash-completion
  :config
  (autoload 'bash-completion-dynamic-complete
    "bash-completion"
    "BASH completion hook")
  (add-hook 'shell-dynamic-complete-functions
	    'bash-completion-dynamic-complete))

(provide 'rez-term)
