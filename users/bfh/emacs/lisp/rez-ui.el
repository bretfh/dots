;; -*- lexical-binding: t -*-

;;(load-theme 'kaolin-shiva t)
;;(load-theme 'doom-moonlight t)
;;(load-theme 'doom-dark+ t)
(load-theme 'doom-monokai-pro t)
(blink-cursor-mode -1)

(use-package shr-tag-pre-highlight
  :after shr
  :config
  (add-to-list 'shr-external-rendering-functions
	       '(pre . shr-tag-pre-highlight))
  (with-eval-after-load 'eww
    (advice-add 'eww-display-html :around
		'eww-display-html--override-shr-external-rendering-functions)))

;; (dolist (face '(window-divider
;; 		window-divider-first-pixel
;; 		window-divider-last-pixel
;; 		))
;;   (face-spec-reset-face face)
;;   (set-face-foreground face (face-attribute 'default :background)))

;; (set-face-background 'fringe (face-attribute 'default :background))
;; (set-face-background 'internal-border "grey22")

(unless (display-graphic-p)
  (defun xterm-title-update ()
    (interactive)
    (send-string-to-terminal (concat "\033]1; " (buffer-name) "\007"))
    (if buffer-file-name
	(send-string-to-terminal (concat "\033]2; " (buffer-file-name) "\007"))
      (send-string-to-terminal (concat "\033]2; " (buffer-name) "\007"))))
  (add-hook 'post-command-hook 'xterm-title-update)
  (set-face-background 'default "unspecified-bg"))

(use-package tabspaces
    :demand t
  :commands (tabspaces-switch-or-create-workspace
             tabspaces-open-or-create-project-and-workspace)
  :config
  ;;(tab-bar-mode)
  ;;(tabspaces-mode)
  :custom
  (tabspaces-use-filtered-buffers-as-default t)
  (tabspaces-default-tab "Default")
  (tabspaces-remove-to-default t)
  (tabspaces-include-buffers '("*scratch*"))
  (tabspaces-initialize-project-with-todo t)
  (tabspaces-todo-file-name "project-todo.org")
  (tabspaces-session nil)
  (tabspaces-session-auto-restore nil))

(use-package window
  :ensure nil
  :config
  (setq-default bidi-display-reordering  'left-to-right
 		bidi-paragraph-direction 'nil
		fringes-outside-margins  t)
  (setq-default truncate-lines t)
  (setq-default display-line-numbers-width 4)

  (add-hook 'window-configuration-change-hook  #'(lambda () (set-window-scroll-bars (minibuffer-window) nil nil)))

  ;;(setq switch-to-buffer-obey-display-actions t)
  (setq split-height-threshold        nil
	split-width-threshold         200
	highlight-nonselected-windows nil
	auto-window-vscroll           nil
	fast-but-imprecise-scrolling  t
	ring-bell-function            'ignore
	scroll-conservatively         101)

  (setq pixel-scroll-precision-large-scroll-height 10)
  ;;(pixel-scroll-precision-mode)
  )

(use-package kind-icon)
(use-package all-the-icons)
(use-package all-the-icons-completion :config (all-the-icons-completion-mode))

(use-package magit
  :bind ("C-x g" . magit-status)
  :config
  (put 'magit-clean 'disabled nil))

(use-package git-gutter
  :hook (prog-mode . git-gutter-mode)
  :config
  (setq git-gutter:update-interval 0.02))

(use-package git-gutter-fringe
  :config
  (define-fringe-bitmap 'git-gutter-fr:added [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:modified [224] nil nil '(center repeated))
  (define-fringe-bitmap 'git-gutter-fr:deleted [128 192 224 240] nil nil 'bottom))

(use-package tab-bar
  :config
  (tab-bar-history-mode t)
  (setq tab-bar-show              nil
	tab-bar-close-button-show nil
	tab-bar-new-button-show   nil
	tab-bar-forward-button    nil
	tab-bar-back-button       nil
	tab-bar-tab-hints t
	tab-bar-select-tab-modifiers '(super)
	tab-bar-auto-width nil)
  (setq tab-bar-separator " "))

(set-face-foreground 'vertical-border
		     (face-background 'vertical-border nil t))
;;(setq tab-bar-format '(tab-bar-format-align-right tab-bar-format-global))
;; TODO: when not in wm

;;(global-set-key (kbd "s-{") 'tab-bar-switch-to-prev-tab)
;;(global-set-key (kbd "s-}") 'tab-bar-switch-to-next-tab)
;;(global-set-key (kbd "s-t") 'tab-bar-new-tab)
;;(global-set-key (kbd "s-w") 'tab-bar-close-tab)


(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'electric-pair-mode)
(add-hook 'prog-mode-hook #'show-paren-mode)

(setq treesit-font-lock-level 4)



;;(defvar vex-workspace-names '("Default") "List of workspace names.")
(defgroup vex-tab-bar nil
  "Options related to my custom tab-bar."
  :group 'tab-bar)

(defgroup vex-tab-bar-faces nil
  "Faces for the tab-bar."
  :group 'vex-tab-bar)

(defface vex-tab-bar-workspace-tab
  '((t :inherit default))
  "Face for a workspace tab."
  :group 'vex-tab-bar-faces)

(defface vex-tab-bar-selected-workspace-tab
  '((t :inherit (highlight vex-tab-bar-workspace-tab)))
  "Face for a selected workspace tab."
  :group 'vex-tab-bar-faces)

(defun vex-center-string (width string)
  (let ((padding (/ (- width (string-width string)) 2)))
    (concat (make-string padding ?\s) string)))

(defun vex-tab-bar--format-left ()
  (if buffer-file-name
      (abbreviate-file-name buffer-file-name)
    "%b"))

(defun vex-tab-bar--format-right ()
  (format "        %dx%d"
          (frame-width)
          (frame-height)))
(defvar vex-workspace-names '("Default" "Workspace1" "Workspace2") "List of workspace names.")

(defun vex-tab-name-function ()
  (let* ((current-tab (tab-bar--current-tab))
         (tab-index (seq-position (tab-bar-tabs)
                                  current-tab
                                  (lambda (a b) (eq (car a) (car b))))))
    (or (nth tab-index vex-workspace-names) "Unnamed")))

(defun vex-tab-bar--workspaces ()
  "Generate the string to display in the tab bar."
  (let* ((left (vex-tab-bar--format-left))
         (right (vex-tab-bar--format-right))
         (tabs (tab-bar-tabs))
         (current-tab (tab-bar--current-tab))
         (current-tab-index (seq-position tabs current-tab
                                          (lambda (a b) (eq (car a) (car b)))))
         (tabs-string (mapconcat (lambda (tab index)
                                   (let ((tab-name (nth index vex-workspace-names))
                                         (face (if (eq index current-tab-index)
                                                   'vex-tab-bar-selected-workspace-tab
                                                 'vex-tab-bar-workspace-tab)))
                                     (propertize (format " %s " tab-name) 'face face)))
                                 tabs
                                 (number-sequence 0 (1- (length tabs)))
                                 " "))
         (total-width (frame-width))
         (tabs-width (string-width tabs-string))
         (space-between (max 0 (- total-width (string-width left) tabs-width (string-width right))))
         (padding-left (make-string (/ space-between 2) ?\s))
         (padding-right (make-string (- space-between (length padding-left)) ?\s)))
    (format "%s%s%s%s%s"
            left
            padding-left
            tabs-string
            padding-right
            right)))

;;(setq tab-bar-tab-name-function 'vex-tab-name-function)
;;(customize-set-variable 'tab-bar-format '(tab-bar-format-global))
;;(customize-set-variable 'global-mode-string '((:eval (vex-tab-bar--workspaces)) " "))
;;(vex-tab-bar--workspaces)

(provide 'rez-ui)
