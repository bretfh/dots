;; -*- lexical-binding: t -*-

(require 'wdired)
(require 'bind-key)

;; common lisp
(setq inferior-lisp-program "ros -Q run")

;; grab bag
(setq kill-buffer-query-functions
      (remq 'process-kill-buffer-query-function
            kill-buffer-query-functions)
      echo-keystrokes .05 
      enable-recursive-minibuffers t
      sentence-end-double-space nil 
      help-window-select t 
      enable-local-variables :all)

;; Saving history
(setq savehist-file "~/.emacs.d/cache/savehist")
(setq history-length 30000)
(setq history-delete-duplicates nil)
(setq savehist-save-minibuffer-history t)

;; Saving your place in buffers, files, ...
(setq save-place-file "~/.emacs.d/cache/saveplace")
(setq save-place-forget-unreadable-files t)

;; Dired
(setq dired-recursive-copies 'always)
(setq dired-recursive-deletes 'always)
(setq dired-listing-switches "-AFhlv --group-directories-first")
(setq dired-dwim-target t)

(use-package dired-subtree :ensure t
  :config
  (bind-key "<tab>" #'dired-subtree-toggle dired-mode-map)
  (bind-key "<backtab>" #'dired-subtree-cycle dired-mode-map))

;; Dired subtree
;; (bind-keys :package dired-subtree :map dired-mode-map
;; 	   ("TAB" . dired-subtree-toggle)
;; 	   ("<C-tab>" . dired-subtree-cycle)
;; 	   ("<S-iso-lefttab>" . dired-subtree-remove))

;; Dired git info
;;(setq dgi-commit-message-format "%h\t%s\t%cr")
;;(bind-keys :package dired-git-info :map dired-mode-map
;;	   (")" . dired-git-info-mode))

;; Wdired
(setq wdired-allow-to-change-permissions t
      wdired-create-parent-directories t)

;; Wgrep
(setq wgrep-auto-save-buffer t)
(setq wgrep-change-readonly-file t)


(setq password-cache-expiry (* 60 15))
(setq use-dialog-box nil)


(add-hook 'dired-mode-hook #'dired-hide-details-mode)
(add-hook 'dired-mode-hook #'hl-line-mode)

(savehist-mode)


(provide 'rez-misc)
