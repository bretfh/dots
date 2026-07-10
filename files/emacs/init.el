;; -*- lexical-binding: t -*-
;;; init: an emacs config
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;;; Core settings ----
;;;; perf tweaks
(setq gc-cons-threshold (* 80 1024 1024)
      gc-cons-percentage 0.2
      load-prefer-newer noninteractive
      native-comp-async-report-warnings-errors 'silent)
;; dont check files against file type
(defvar file-name-handler-alist-old file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'after-init-hook
          #'(lambda ()
              (setq file-name-handler-alist file-name-handler-alist-old)))

;;;; place on display
(when window-system
  (let* ((big-monitor "C32HG7x")
         (starfighter-internal "0x08cf")
         (office "HDMI-1")
         (work-mbp "NS")
         (current (cdr (assoc 'source (car (display-monitor-attributes-list))))))
    (cond
     ((string= current work-mbp)
      (set-frame-position (selected-frame) 1840 -5)
      (set-frame-size (selected-frame) 180 55))
     ((string= current big-monitor)
      (set-frame-position (selected-frame) 0 0)
      (set-frame-size (selected-frame) 200 80))
     ((string= current office)
      (set-frame-position (selected-frame) 0 0)
      (set-frame-size (selected-frame) 140 65))
     ((string= current starfighter-internal)
      (set-frame-position (selected-frame) 0 0)
      (set-frame-size (selected-frame) 120 40)))))

;; terminal specific -- applied PER FRAME, never globally at load. Under the
;; emacs daemon (display-graphic-p) is nil at init, so the old unconditional
;; (set-face-background 'default "unspecified-bg") poisoned the global default
;; face and made every later GUI frame fail with (error "Undefined color").
(defun xterm-title-update ()
  (interactive)
  (unless (display-graphic-p)
    (send-string-to-terminal (concat "\033]1; " (buffer-name) "\007"))
    (if buffer-file-name
        (send-string-to-terminal (concat "\033]2; " (buffer-file-name) "\007"))
      (send-string-to-terminal (concat "\033]2; " (buffer-name) "\007")))))

(defun terminal-frame-setup (&optional frame)
  "Apply terminal-only tweaks to FRAME, leaving GUI frames untouched.
Sets the background frame-locally (passing FRAME), so it never pollutes the
global default face the daemon's GUI frames inherit."
  (let ((frame (or frame (selected-frame))))
    (unless (display-graphic-p frame)
      (set-face-background 'default "unspecified-bg" frame)
      (add-hook 'post-command-hook 'xterm-title-update))))

(add-hook 'after-make-frame-functions 'terminal-frame-setup)
(terminal-frame-setup)

;;;; Basic Defaults
(setopt auto-hscroll-mode 'current-line
        auto-save-interval 64
        auto-save-timeout 2
        fill-column 80
        history-delete-duplicates t
        history-length 200
        message-log-max 16384
        redisplay-dont-pause t
        undo-limit 800000
        x-stretch-cursor t)
;;;; File Handling ---- files.el
(setopt completion-ignored-extensions
        '(".a" ".aux" ".bbl" ".bin" ".blg" ".class" ".cp" ".cps" ".elc" ".fmt" ".fn"
          ".fns" ".git/" ".glo" ".glob" ".gmo" ".hg/" ".idx" ".ky" ".kys" ".la" ".lib"
          ".ln" ".lo" ".lof" ".lot" ".mem" ".mo" ".o" ".pg" ".pgs" ".pyc" ".pyo" ".so"
          ".tfm" ".toc" ".tp" ".tps" ".v.d" ".vio" ".vo" ".vok" ".vos" ".vr" ".vrs" "~"))
(setopt ;;backup-directory-alist '(("." . "~/.emacs.d/backups"))
 delete-old-versions t
 directory-free-space-args "-kh"
 large-file-warning-threshold nil
 save-abbrevs 'silently
 trash-directory "~/.Trash"
 version-control t)
;;;; Basic Editing ---- simple.el
(setopt backward-delete-char-untabify-method 'untabify
        indent-tabs-mode nil
        kill-do-not-save-duplicates t
        kill-ring-max 500
        next-line-add-newlines nil
        prettify-symbols-unprettify-at-point 'right-edge
        tab-width 4
        sentence-end-double-space nil
        show-paren-delay 0)
;;;; Window behaviors ---- window.el
(setopt same-window-buffer-names 
        '("*eshell*" "*shell*" "*mail*" "*inferior-lisp*" "*ielm*")
        switch-to-buffer-preserve-window-point t
        warning-minimum-log-level :error
        frame-title-format nil
        window-divider-default-bottom-width 1
        window-divider-default-places 'bottom-only)
;;;; System Behavior
(setopt disabled-command-function nil  ; enable all commands
        default-input-method nil
        inhibit-startup-message t
        inhibit-default-init t
        inhibit-startup-echo-area-message user-login-name)
;;;; Process and Buffer Management
(setopt kill-buffer-query-functions
        (delq 'process-kill-buffer-query-function
              kill-buffer-query-functions))
(setopt use-short-answers t
        make-backup-files nil
        auto-save-no-message t
        kill-buffer-delete-auto-save-files t
        enable-recursive-minibuffers t
        window-combination-resize t
        truncate-partial-width-windows nil
        echo-keystrokes .05
        password-cache-expiry (* 60 15)
        use-dialog-box nil)
;;;; Help and History ---- history.el
(setopt help-window-select t
        help-window-keep-selected t
        ;;        savehist-file "~/.emacs.d/cache/savehist"
        history-length 50000
        history-delete-duplicates t
        savehist-save-minibuffer-history t
        ;;        save-place-file "~/.emacs.d/cache/saveplace"
        save-place-forget-unreadable-files t)
;;;; Dired Configuration ---- dired.el
(setopt wgrep-auto-save-buffer t
        wgrep-change-readonly-file t
        dired-use-ls-dired t
        insert-directory-program "ls"
        dired-auto-revert-buffer #'dired-directory-changed-p
        dired-dwim-target t
        dired-recursive-copies 'always 
        dired-recursive-deletes 'always
        dired-listing-switches "-Ahl --group-directories-first")
;;;; general visuals
(display-time-mode)
(display-battery-mode)
(savehist-mode)
(save-place-mode)
;;(setq display-line-numbers-type 'visual)
(setq display-line-numbers-type t)
;;(blink-cursor-mode -1)

;;;; Basic Bindings
(global-set-key [escape] 'keyboard-escape-quit)
(keymap-global-set "M-o" 'other-window)
(keymap-global-set "C-w" 'backward-kill-word)
(keymap-global-set "C-x C-k" 'kill-region)
(keymap-global-set "C-x C-m" 'execute-extended-command)
(keymap-global-set "C-z" 'zap-up-to-char)
(global-unset-key (kbd "C-x C-b"))
;;(global-set-key (kbd "s-{") 'tab-bar-switch-to-prev-tab)
;;(global-set-key (kbd "s-}") 'tab-bar-switch-to-next-tab)
;;(global-set-key (kbd "s-t") 'tab-bar-new-tab)
;;(global-set-key (kbd "s-w") 'tab-bar-close-tab)

;;;; Hooks
(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'prog-mode-hook #'electric-pair-mode)
(add-hook 'prog-mode-hook #'show-paren-mode)
(add-hook 'dired-mode-hook #'dired-hide-details-mode)
(add-hook 'dired-mode-hook #'hl-line-mode)

;;; Package manager init
;; bootstrap Elpaca package manager
(defvar elpaca-installer-version 0.9)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (< emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))
(elpaca elpaca-use-package
  ;; Enable use-package :ensure support for Elpaca.
  (elpaca-use-package-mode))

;; If packages arent explicityl disabled, assume they are needed
;;(setq use-package-always-ensure t)

;; 

;;; Package list
;; Vi the mark of the beast
;;;; Emulate vim/helix & w/e we car about keybinds & modal editing
(use-package evil
  :demand t
  :bind (("<escape>" . keyboard-escape-quit))
  :init
  (setq evil-want-keybinding nil)
  :custom
  (evil-move-cursor-back nil)
  (evil-undo-system 'undo-fu)
  (evil-want-C-u-scroll t)
  :config
  (setq evil-want-C-u-scroll t
        evil-want-C-u-delete t
        evil-want-C-g-bindings t
        evil-start-of-line t
        evil-search-module 'evil-search
        evil-ex-search-highlight-all t
        evil-ex-substitute-case 'sensitive
        evil-undo-system 'undo-redo
        evil-ex-complete-emacs-commands t
        evil-ex-visual-char-range t
        evil-want-Y-yank-to-eol t
        evil-symbol-word-search t
        evil-split-window-below t evil-vsplit-window-right t
        evil-mode-line-format nil
        evil-insert-state-modes '(comint-mode)
        evil-motion-state-modes ()
        evil-emacs-state-modes '(debugger-mode))
  (evil-mode 1)
  (evil-set-leader 'motion (kbd "SPC"))
  (evil-define-operator evil-comment (start end)
    "Toggle comment from START to END."
    (interactive "<r>")
    (comment-or-uncomment-region start end))
  (evil-define-key* 'normal help-mode-map
    "\C-t" 'help-go-back
    "s" 'help-view-source)
  (evil-define-key* 'normal 'global
    "\C-^" 'evil-switch-to-windows-last-buffer
    "U" 'vundo
    [f9] 'compile-or-recompile
    (kbd "<leader>u") 'universal-argument
    (kbd "<leader>h") 'help-command
    (kbd "<leader>w") 'evil-window-map
    ;; Buffer and file commands with consult
    (kbd "<leader>b") 'consult-buffer
    (kbd "<leader>B") 'consult-project-buffer
    (kbd "<leader>f") 'find-file
    (kbd "<leader>F") 'dired-jump
    ;; Search commands
    (kbd "<leader>s") 'consult-line
    (kbd "<leader>r") 'consult-ripgrep
    (kbd "<leader>i") 'consult-imenu
    (kbd "<leader>o") 'consult-outline
    (kbd "<leader>e") 'pp-eval-last-sexp (kbd "<leader>E") 'eval-defun
    (kbd "<leader>v") 'magit
    (kbd "<leader>d") 'dirvish-side
    (kbd "<leader>p") 'consult-fd
    (kbd "<leader>P") 'my/consult-project-switch
    (kbd "<leader>T") 'tabspaces-project-switch-project-open-file
    (kbd "<leader>tt") 'tree-sitter-hl-mode
    (kbd "<leader>tl") 'display-line-numbers-mode
    (kbd "<leader>tr") 'rainbow-delimiters-mode
    (kbd "<leader>tb") 'toggle-breadcrumb-header)
  (evil-define-key 'normal dired-mode-map
    (kbd "SPC") nil)
  (evil-define-key 'normal dired-mode-map
    "f" 'find-file "I" 'dired-toggle-read-only)
  (evil-define-key nil wdired-mode-map
    [remap evil-write] 'wdired-finish-edit))
;; Vi everywhere else
(use-package evil-collection
  :after evil
  :config
  (setq evil-want-integration t)
  (evil-collection-init))
;; vim-lime tab's at top of frame
(use-package vim-tab-bar
  :disabled
  :config
  (add-hook 'after-init-hook #'vim-tab-bar-mode))
;; keep undo history
(use-package undo-fu)
;; keep file's undo history between emacs sessions
(use-package undo-fu-session
  :config
  (undo-fu-session-global-mode))
;; make undo history a tree on-the-fly
(use-package vundo
  :elpaca (vundo :host github :repo "casouri/vundo" :files (:defaults "*.el")))

;;; Completions
(use-package vertico
  :ensure nil
  :config
  (setq vertico-scroll-margin 0)
  (setq vertico-count 10)
  (setq vertico-resize nil)
  ;; Optionally enable cycling for `vertico-next' and `vertico-previous'.
  ;; (setq vertico-cycle t)
  (define-key vertico-map "?" #'minibuffer-completion-help)
  (define-key vertico-map (kbd "M-RET") #'minibuffer-force-complete-and-exit)
  (define-key vertico-map (kbd "M-TAB") #'minibuffer-complete)
  (vertico-mode))

(use-package vertico-directory
  :after vertico :ensure nil
  :bind (:map vertico-map
              ("RET" . vertico-directory-enter)
              ("DEL" . vertico-directory-delete-char)
              ("M-DEL" . vertico-directory-delete-word))
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

(use-package vertico-quick
  :after vertico :ensure nil
  :bind (:map vertico-map
              ("C-i" . vertico-quick-insert)
              ("C-o" . vertico-quick-exit)))

(use-package vertico-repeat
  :after vertico :ensure nil
  :bind ("C-c r" . vertico-repeat)
  :hook (minibuffer-setup . vertico-repeat-save))

(use-package vertico-indexed :after vertico :ensure nil)

(use-package vertico-mouse
  :after vertico :ensure nil
  :defer 1
  :config (vertico-mouse-mode))

(use-package vertico-posframe
  :after (vertico posframe)
  :config
  (setq vertico-posframe-parameters
        '((undecorated . nil)
          (undecorated-rounded . t)
          (left-fringe . 8)
          (right-fringe . 8)))
  (defun my/posframe-poshandler-frame-bottom-right-corner (info)
    (cons (- (plist-get info :parent-frame-width)
             (plist-get info :posframe-width))
          (- (plist-get info :parent-frame-height)
             (plist-get info :posframe-height)
             (plist-get info :mode-line-height)
             (plist-get info :minibuffer-height))))
  (setq vertico-posframe-poshandler 'my/posframe-poshandler-frame-bottom-right-corner))

(use-package vertico-multiform
  :after vertico-posframe :ensure nil
  :config
  (context-menu-mode t)
  (setq vertico-multiform-commands
        '((execute-extended-command posframe
                                    (vertico-posframe-poshandler . posframe-poshandler-frame-top-center))
          (consult-line buffer
                        (vertico-buffer-display-action . (display-buffer-in-side-window
                                                          (side . right)
                                                          (window-width . 0.5))))
          (consult-imenu buffer indexed
                         (vertico-buffer-display-action . (display-buffer-in-side-window
                                                           (side . left)
                                                           (window-width . 0.3))))
          (consult-outline buffer
                           (vertico-buffer-display-action . (display-buffer-in-side-window
                                                             (side . right)
                                                             (window-width . 0.5))))
          (consult-project-buffer buffer
                                  (vertico-buffer-display-action . (display-buffer-in-side-window
                                                                    (side . right)
                                                                    (window-width . 0.5))))
          (consult-buffer buffer
                          (vertico-buffer-display-action . (display-buffer-in-side-window
                                                            (side . right)
                                                            (window-width . 0.5))))
          (consult-ripgrep buffer
                           (vertico-buffer-display-action . (display-buffer-in-side-window
                                                             (side . bottom)
                                                             (window-height . 0.5))))
          (consult-grep buffer
                        (vertico-buffer-display-action . (display-buffer-in-side-window
                                                          (side . left)
                                                          (window-width . 0.4))))
          (t posframe
             (vertico-posframe-poshandler . posframe-poshandler-frame-top-center))))
  (setq vertico-multiform-categories
        '((file (vertico-sort-function . vertico-sort-directories-first))
          (buffer (vertico-sort-function . vertico-sort-alpha))
          (consult-grep buffer)))
  (defun vertico-multiform-posframe ()
    (interactive)
    (vertico-multiform--display-toggle 'vertico-posframe-mode))
  (define-key vertico-multiform-map (kbd "M-P") #'vertico-multiform-posframe)
  (vertico-multiform-mode))

;;;; orderless
(use-package orderless
  :ensure nil
  :config
  ;;(setq completions-detailed t)
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion))))

  (defun crm-indicator (args)
    (cons (format "[CRM%s] %s"
                  (replace-regexp-in-string
                   "\\`\\[.*?]\\*\\|\\[.*?]\\*\\'" ""
                   crm-separator)
                  (car args))
          (cdr args)))

  (setq minibuffer-prompt-properties
        '(read-only t cursor-intangible t face minibuffer-prompt))
  (setq enable-recursive-minibuffers t))

;;;; consult
(use-package consult
  :ensure nil
  :after vertico
  :bind (;; C-c bindings (mode-specific-map)
         ("C-c h" . consult-history)
         ("C-c m" . consult-mode-command)
         ("C-c k" . consult-kmacro)
         ;; C-x bindings (ctl-x-map)
         ("C-x M-:" . consult-complex-command)     ;; orig. repeat-complex-command
         ;;         ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
         ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
         ("C-x 5 b" . consult-buffer-other-frame)  ;; orig. switch-to-buffer-other-frame
         ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
         ("C-x p b" . consult-project-buffer)      ;; orig. project-switch-to-buffer
         ;; Custom M-# bindings for fast register access
         ("M-#" . consult-register-load)
         ("M-'" . consult-register-store)          ;; orig. abbrev-prefix-mark (unrelated)
         ("C-M-#" . consult-register)
         ;; Other custom bindings
         ("M-y" . consult-yank-pop)                ;; orig. yank-pop
         ;; M-g bindings (goto-map)
         ("M-g e" . consult-compile-error)
         ("M-g f" . consult-flymake)               ;; Alternative: consult-flycheck
         ("M-g g" . consult-goto-line)             ;; orig. goto-line
         ("M-g M-g" . consult-goto-line)           ;; orig. goto-line
         ("M-g o" . consult-outline)               ;; Alternative: consult-org-heading
         ("M-g m" . consult-mark)
         ("M-g k" . consult-global-mark)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ;; M-s bindings (search-map)
         ("M-s d" . consult-find)
         ("M-s D" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history)         ;; orig. isearch-edit-string
         ("M-s e" . consult-isearch-history)       ;; orig. isearch-edit-string
         ("M-s l" . consult-line)                  ;; needed by consult-line to detect isearch
         ("M-s L" . consult-line-multi)            ;; needed by consult-line to detect isearch
         ;; Minibuffer history
         :map minibuffer-local-map
         ("M-s" . consult-history)                 ;; orig. next-matching-history-element
         ("M-r" . consult-history))                ;; orig. previous-matching-history-element

  :hook (completion-list-mode . consult-preview-at-point-mode)
  :init
  (setq register-preview-delay 0.5
        register-preview-function #'consult-register-format)
  (advice-add #'register-preview :override #'consult-register-window)
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  :config
  ;; Optionally configure preview. The default value
  ;; is 'any, such that any key triggers the preview.
  ;; (setq consult-preview-key 'any)
  ;; (setq consult-preview-key (kbd "M-."))
  ;; (setq consult-preview-key (list (kbd "<S-down>") (kbd "<S-up>")))
  ;; For some commands and buffer sources it is useful to configure the
  ;; :preview-key on a per-command basis using the `consult-customize' macro.
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file consult-xref
   consult--source-bookmark consult--source-file-register
   consult--source-recent-file consult--source-project-recent-file
   ;; :preview-key (kbd "M-.")
   :preview-key '(:debounce 0.4 any))

  ;; Optionally configure the narrowing key.
  ;; Both < and C-+ work reasonably well.
  (setq consult-narrow-key "<") ;; (kbd "C-+")

  (defun my/consult-project-switch ()
    "Pick a known project and open it with `consult-fd' rooted there."
    (interactive)
    (let* ((projects (project-known-project-roots))
           (project-dir (consult--read projects
                                       :prompt "Switch to project: "
                                       :category 'file
                                       :history 'file-name-history
                                       :sort nil)))
      (when project-dir
        (let ((default-directory project-dir))
          (consult-fd)))))

  ;; Optionally make narrowing help available in the minibuffer.
  ;; You may want to use `embark-prefix-help-command' or which-key instead.
  ;; (define-key consult-narrow-map (vconcat consult-narrow-key "?") #'consult-narrow-help)

  ;; By default `consult-project-function' uses `project-root' from project.el.
  ;; Optionally configure a different project root function.
  ;; There are multiple reasonable alternatives to chose from.
  ;;;; 1. project.el (the default)
  ;; (setq consult-project-function #'consult--default-project--function)
  ;;;; 2. projectile.el (projectile-project-root)
  ;; (autoload 'projectile-project-root "projectile")
  ;; (setq consult-project-function (lambda (_) (projectile-project-root)))
  ;;;; 3. vc.el (vc-root-dir)
  ;; (setq consult-project-function (lambda (_) (vc-root-dir)))
  ;;;; 4. locate-dominating-file
  ;; (setq consult-project-function (lambda (_) (locate-dominating-file "." ".git")))
  )

;;;; embark
(use-package embark
  :ensure t
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command)
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

(use-package embark-consult
  :ensure t
  :hook (embark-collect-mode . consult-preview-at-point-mode))

;;;; cape
(use-package cape
  :ensure nil
  :config
  (advice-add 'pcomplete-completions-at-point :around #'cape-wrap-silent)
  (advice-add 'pcomplete-completions-at-point :around #'cape-wrap-purify)
  (add-to-list 'completion-at-point-functions #'cape-file))

;;;; marginalia
(use-package marginalia
  :ensure nil
  :after vertico
  :config
  (setq marginalia-align 'right)
  (marginalia-mode))

;;;; corfu
(use-package corfu
  :ensure nil
  :after kind-icon
  :config
  (customize-set-variable 'kind-icon-default-face 'corfu-default)
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter)
  (advice-add #'completing-read-multiple :filter-args #'crm-indicator)
  (add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)
  ;;(add-hook 'marginalia-mode-hook #'all-the-icons-completion-marginalia-setup)
  (add-hook 'eshell-mode-hook #'corfu-mode)
  (global-corfu-mode)
  (defun corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer if `completion-at-point' is bound."
    (when (where-is-internal #'completion-at-point (list (current-local-map)))
      ;; (setq-local corfu-auto nil) ;; Enable/disable auto completion
      (setq-local corfu-echo-delay nil ;; Disable automatic echo and popup
                  corfu-popupinfo-delay nil)
      (corfu-mode 1)))
  (add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer)
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  (corfu-auto-prefix 1)
  (corfu-auto-delay 0.1)
  (corfu-quit-no-match 'separator)
  (corfu-excluded-modes '(term eshell org-mode mu4e-compose-mode)))

;;; VC/Git
;;;; magit
(use-package transient :ensure t)
(use-package magit
  :ensure nil
  :after transient
  :bind ("C-x g" . magit-status)
  :config
  (put 'magit-clean 'disabled nil))

;;;; consult-gh ---- github browsing through consult
(use-package consult-gh
  :ensure t :defer t :after consult
  :custom
  (consult-gh-default-clone-directory "~/projects")
  (consult-gh-show-preview t)
  (consult-gh-preview-key "C-o")
  (consult-gh-repo-action #'consult-gh--repo-browse-files-action)
  (consult-gh-large-file-warning-threshold 2500000)
  (consult-gh-confirm-name-before-fork nil)
  (consult-gh-confirm-before-clone t)
  (consult-gh-notifications-show-unread-only nil)
  (consult-gh-default-interactive-command #'consult-gh-transient)
  (consult-gh-prioritize-local-folder nil)
  (consult-gh-group-dashboard-by :reason)
  (consult-gh-repo-preview-major-mode nil)
  (consult-gh-preview-major-mode 'org-mode)
  :config
  (add-to-list 'savehist-additional-variables 'consult-gh--known-orgs-list)
  (add-to-list 'savehist-additional-variables 'consult-gh--known-repos-list)
  (consult-gh-enable-default-keybindings))

(use-package consult-gh-embark
  :ensure t :defer t :after (consult-gh embark)
  :config (consult-gh-embark-mode +1))

(use-package diff-hl
  :ensure nil
  :defer 1
  :hook (((prog-mode org-mode markdown-mode latex-mode) . diff-hl-mode)
         (dired-mode . diff-hl-dired-mode))
  :config
  (unless (display-graphic-p) (diff-hl-margin-mode))
  (add-hook 'magit-pre-refresh-hook 'diff-hl-magit-pre-refresh)
  (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh)
  (setq diff-hl-draw-borders nil)
  (diff-hl-flydiff-mode 1)
  (global-diff-hl-mode 1))
;;; Docs
(use-package devdocs
  :ensure t
  :disabled
  :hook
  (devdocs #'(lambda () (kill-local-variable 'truncate-lines))))

;;; UI ---- general look and feel
;;;;; side bar

;;;;; breadcrumbs/filepath in header line
(use-package breadcrumb
  :ensure (:host github :repo "joaotavora/breadcrumb")
  :custom
  (bc-imenu-max-length 0.3)
  (bc-project-max-length 0.3)
  (bc-imenu-crumb-separator " > ")
  (bc-project-crumb-separator "/")
  :config
  (require 'svg)
  (require 'cl-lib)
  (require 'subr-x)
  (require 'eieio)

  ;; Cache variables
  (defvar-local my/header-svg-cache nil)
  (defvar-local my/header-cache-key nil)
  
  ;; pre-calculate character sizes
  (defconst my/char-width-small (* 12 0.6))
  (defconst my/char-width-large (* 14 0.6))
  (defconst my/font-height-1 12)
  (defconst my/font-height-2 14)
  (defconst my/total-height (+ my/font-height-1 my/font-height-2 8))

  (defun my/get-breadcrumb ()
    (let ((breadcrumb-mode nil))
      (let ((res (breadcrumb--header-line)))
        (if (stringp res) res (format-mode-line res)))))

  ;; Extract function/magit context
  (defun my/get-context ()
    (cond
     ((and (fboundp 'magit-current-section)
           (derived-mode-p 'magit-section-mode))
      (save-excursion
        (goto-char (window-start))
        (when-let ((section (magit-current-section)))
          (when (and (slot-boundp section 'content)
                     (/= (window-start) (eieio-oref section 'start)))
            (string-trim
             (buffer-substring
              (eieio-oref section 'start)
              (eieio-oref section 'content)))))))
     ((derived-mode-p 'prog-mode)
      (save-excursion
        (when (> (window-start) 1)
          (goto-char (window-start))
          (beginning-of-defun)
          (font-lock-ensure (point) (line-end-position))
          (string-trim (buffer-substring (point) (line-end-position))))))))

  (defun my/create-header-svg (crumb-str context-str)
    (let* ((width (window-pixel-width))
           (svg (svg-create width my/total-height))
           (background (catppuccin-color 'base))
           (text-color (catppuccin-color 'subtext1))
           (accent-color (catppuccin-color 'blue))
           (highlight-color (catppuccin-color 'lavender)))
      
      (svg-rectangle svg 0 0 width my/total-height :fill background)
      
      ;; parse and render propertized text with proper colors
      (when crumb-str
        (let ((parts (split-string crumb-str ">"))
              (x-pos 0))
          (dolist (part parts)
            (let* ((trimmed-part (string-trim part))
                   (part-color (if (string-match-p "/\\|\\." trimmed-part) 
                                   accent-color 
                                 text-color)))
              (svg-text svg trimmed-part
                        :font-family "Fira Code"
                        :font-size my/font-height-1
                        :fill part-color
                        :x x-pos
                        :y (+ 2 my/font-height-1))
              (setq x-pos (+ x-pos (* (length trimmed-part) my/char-width-small) 10))
              (when (< x-pos width)
                (svg-text svg ">"
                          :font-family "Fira Code"
                          :font-size my/font-height-1
                          :fill text-color
                          :x x-pos
                          :y (+ 2 my/font-height-1))
                (setq x-pos (+ x-pos 20)))))))
      
      (when context-str
        (svg-text svg context-str
                  :font-family "Fira Code"
                  :font-size my/font-height-2
                  :fill highlight-color
                  :x 0
                  :y (+ 4 my/font-height-1 my/font-height-2)))
      
      svg))

  (defun my/header-line ()
    "Generate svg powered mult-line header on frame with some caching of previous results."
    (let* ((crumb (my/get-breadcrumb))
           (context (my/get-context))
           (crumb-str (if (and crumb (> (length crumb) 60))
                          (concat (substring crumb 0 57) "...")
                        crumb))
           (context-str (if (and context (> (length context) 60))
                            (concat (substring context 0 57) "...")
                          context))
           (cache-key (concat (or crumb-str "") "|" (or context-str ""))))
      
      (unless (string= cache-key my/header-cache-key)
        (setq my/header-svg-cache
              (svg-image (my/create-header-svg crumb-str context-str)
                         :ascent 100)
              my/header-cache-key cache-key))
      
      (propertize " " 'display my/header-svg-cache)))

  ;; Set up the header line
  (setq breadcrumb-mode nil)
  (setq-default header-line-format '(:eval (my/header-line)))
  (defun my/update-header-on-resize (&rest _)
    "Update the header line when frame is resized."
    (setq my/header-cache-key nil)  ; Force cache invalidation
    (force-mode-line-update t))

  (add-hook 'window-size-change-functions #'my/update-header-on-resize)

  (defun toggle-breadcrumb-header ()
    "Toggle the custom breadcrumb header line in the current buffer."
    (interactive)
    (if header-line-format
        (setq-local header-line-format nil)
      (setq-local header-line-format '(:eval (my/header-line))))
    (force-mode-line-update t))
  )

;;;; modeline
(use-package doom-modeline
  :ensure nil
  :init (doom-modeline-mode 1))

(use-package hide-mode-line
  :ensure nil
  :hook ((dirvish-side-mode . hide-mode-line-mode)
         (completion-list-mode . hide-mode-line-mode)))

;;;; stillness
(use-package stillness-mode
  :ensure (:host github :repo "neeasade/stillness-mode.el"))

;;;; display keybinds and their functions as they're typed
(use-package which-key
  :ensure nil
  :custom
  (which-key-idle-delay 0.0)
  (which-key-popup-type 'custom)
  (which-key-max-display-columns 2)
  :config
  (setq which-key-separator " "
        which-key-prefix-prefix "Goto "
        which-key-show-prefix nil)

  ;; Special descriptions for g prefix commands to match Helix style
  (which-key-add-key-based-replacements
    "g" "Goto"
    "g g" "Goto line number <n> else file start"
    "g e" "Goto last line"
    "g f" "Goto files/URLs in selections"
    "g h" "Goto line start"
    "g l" "Goto line end"
    "g s" "Goto first non-blank in line"
    "g d" "Goto definition"
    "g D" "Goto declaration"
    "g y" "Goto type definition"
    "g r" "Goto references"
    "g i" "Goto implementation"
    "g t" "Goto window top"
    "g c" "Goto window center"
    "g b" "Goto window bottom"
    "g a" "Goto last accessed file"
    "g m" "Goto last modified file"
    "g n" "Goto next buffer"
    "g p" "Goto previous buffer"
    "g k" "Move up"
    "g j" "Move down"
    "g ." "Goto last modification"
    "g w" "Jump to a two-character label")

  :init
  (which-key-mode))

(use-package posframe :ensure t)
(use-package which-key-posframe
  :ensure t
  :after (which-key posframe)
  :custom
  ;;(which-key-posframe-border-width 1)
  ;; Set position handler to bottom-right corner
  ;; doesnt work on MAC
  (which-key-posframe-poshandler 'posframe-poshandler-frame-bottom-right-corner)
  :config
  (setq which-key-posframe-poshandler 'posframe-poshandler-window-bottom-right-corner)
  ;; Fine-tune the position with offsets
  ;; (which-key-posframe-offset-x -10)  ; Negative moves it left from right edge
  ;; (which-key-posframe-offset-y -10)  ; Negative moves it up from bottom edge
  ;; (which-key-posframe-parameters
  ;;  '((left-fringe . 8)
  ;;    (right-fringe . 8)))
  (which-key-posframe-mode))

;;;; scrolling
(use-package ultra-scroll
  :ensure (:host github :repo "jdtsmith/ultra-scroll")
  :init
  (setq scroll-conservatively 101  ; important!
        scroll-margin 0)
  :config
  (ultra-scroll-mode 1))

;;;; fonts ---- fontaine presets
(use-package fontaine
  :ensure t :demand t
  :config
  (setq fontaine-presets
        '((fira
           :default-family "Fira Code"
           :default-height 130
           :italic-slant italic
           :line-spacing 0.2)
          (fira-large
           :default-family "Fira Code"
           :default-height 150
           :italic-slant italic
           :line-spacing 0.2)
          (maple
           :default-family "Maple Mono NF"
           :default-height 130
           :italic-slant italic
           :line-spacing 0.2)
          (maple-large
           :default-family "Maple Mono NF"
           :default-height 150
           :italic-slant italic
           :line-spacing 0.2)
          (regular
           :default-family "Maple Mono NF"
           :default-height 130
           :italic-slant italic
           :line-spacing 0.2)
          (t
           :default-family "Maple Mono NF"
           :default-height 130
           :line-spacing 0.2)))
  (defun my/font-info ()
    "Display current font family and size."
    (interactive)
    (message "Font: %s at %spt"
             (face-attribute 'default :family)
             (/ (face-attribute 'default :height) 10.0)))
  (fontaine-set-preset 'regular)
  (fontaine-mode 1)
  (set-face-attribute 'font-lock-comment-face nil :slant 'italic))

;;;; pulsar ---- flash line on cursor jumps
(use-package pulsar
  :ensure t :defer 2
  :custom
  (pulsar-pulse t)
  (pulsar-delay 0.055)
  (pulsar-iterations 10)
  (pulsar-face 'pulsar-magenta)
  :hook
  ((consult-after-jump imenu-after-jump) . pulsar-recenter-top)
  ((consult-after-jump imenu-after-jump) . pulsar-reveal-entry)
  :config
  (setq pulsar-pulse-functions
        '(recenter-top-bottom
          move-to-window-line-top-bottom
          reposition-window
          bookmark-jump
          other-window
          delete-window
          delete-other-windows
          forward-page
          backward-page
          scroll-up-command
          scroll-down-command
          windmove-right
          windmove-left
          windmove-up
          windmove-down
          tab-new
          tab-close
          tab-next
          org-next-visible-heading
          org-previous-visible-heading
          org-forward-heading-same-level
          org-backward-heading-same-level
          outline-backward-same-level
          outline-forward-same-level
          outline-next-visible-heading
          outline-previous-visible-heading
          outline-up-heading))
  (pulsar-global-mode 1))

;;;; jinx ---- spellchecking
(use-package jinx
  :ensure nil :defer t
  :hook ((text-mode prog-mode conf-mode) . jinx-mode)
  :bind ([remap ispell-word] . jinx-correct)
  :config (setq jinx-languages "en_US"))

(use-package catppuccin-theme
  :ensure nil
  :init 
  ;;TODO
  (defun my/catppuccin-color (name)
    "Get color from catppuccin theme."
    (let ((colors '((base     . "#1e1e2e")  ; Default background
                    (mantle   . "#181825")   ; Slightly darker than base
                    (surface0 . "#313244")   ; Subtle contrast
                    (surface1 . "#45475a")   ; Light contrast
                    (overlay0 . "#6c7086")   ; Muted text
                    (text    . "#cdd6f4")    ; Primary text
                    (lavender . "#b4befe")   ; Accents
                    (blue    . "#89b4fa"))))
      (cdr (assoc name colors))))
  :config
  (defun my/enable-catppuccin (&rest _)
    (unless (memq 'catppuccin custom-enabled-themes)
      (load-theme 'ef-dream t)))
  (if (daemonp)
      (add-hook 'server-after-make-frame-hook #'my/enable-catppuccin)
    (my/enable-catppuccin)))

;;;; Tab bar and tab line 
(use-package tab-bar
  :ensure nil
  :config
  (tab-bar-history-mode t)

  (setq tab-bar-menu-bar-button " ☰")
  (setq tab-bar-format '(tab-bar-format-menu-bar tab-bar-format-tabs-groups
                                                 tab-bar-separator
                                                 tab-bar-format-add-tab))

  (defun tab-bar-tab-name-format-hints (name _tab i)
    (if tab-bar-tab-hints (concat (format " %d " i) "") name))

  (defun tab-bar-tab-group-format-default (tab _i &optional current-p)
    (propertize
     (concat (funcall tab-bar-tab-group-function tab))
     'face (if current-p 'tab-bar-tab-group-current 'tab-bar-tab-group-inactive)))

  (defun emacs-solo/tab-group-from-project ()
    "Call `tab-group` with the current project name as the group."
    (interactive)
    (when-let* ((proj (project-current))
                (name (file-name-nondirectory
                       (directory-file-name (project-root proj)))))
      (tab-group (format "%s:" name))))

  (defun emacs-solo/tab-switch-to-group ()
    "Prompt for a tab group and switch to its first tab."
    (interactive)
    (let* ((tabs (funcall tab-bar-tabs-function))
           (groups (delete-dups (mapcar (lambda (tab)
                                          (funcall tab-bar-tab-group-function tab))
                                        tabs)))
           (group (completing-read "Switch to group: " groups nil t)))
      (let ((i 1) (found nil))
        (dolist (tab tabs)
          (let ((tab-group (funcall tab-bar-tab-group-function tab)))
            (when (and (not found)
                       (string= tab-group group))
              (setq found t)
              (tab-bar-select-tab i)))
          (setq i (1+ i))))))

  (setq tab-bar-show              t
        tab-bar-close-button-show nil
        tab-bar-new-button-show   nil
        tab-bar-forward-button    nil
        tab-bar-back-button       nil
        tab-bar-tab-hints t
        tab-bar-select-tab-modifiers '(super)
        tab-bar-auto-width nil)
  (setq tab-bar-separator " "))

;; legacy tab-bar fragments below (icon glyph) are inert.
(when nil
  (let* ((workspace-name nil)
         (is-current nil)
         ;; placeholder for legacy icon glyph
         ;;                 (icon"")
         (dead nil))))

(defcustom tab-line-tab-min-width 10
  "Minimum width of a tab in characters."
  :type 'integer
  :group 'tab-line)

(defcustom tab-line-tab-max-width 30
  "Maximum width of a tab in characters."
  :type 'integer
  :group 'tab-line)

;;;; Tab lines ---- Opened files in a row of tabs
(use-package tab-line
  :ensure nil
  :config
  ;; Taken ideas from https://andreyor.st/posts/2020-05-10-making-emacs-tabs-look-like-in-atom/
  ;; https://github.com/andreyorst/dotfiles/blob/740d346088ce5a51804724659a895d13ed574f81/.config/emacs/README.org#tabline
  ;;(my/set-tab-theme)
  (defun my/set-tab-theme ()
    (let* ((bg (catppuccin-color 'base))
           (fg (face-attribute 'default :foreground))
           (surface1 (catppuccin-color 'surface1))
           (mantle (catppuccin-color 'mantle))
           (box-width (/ (line-pixel-height) 2)))
      ;; Main tab-line
      (set-face-attribute 'tab-line nil
                          :background mantle
                          :foreground fg
                          :height 1.0
                          :inherit nil
                          :box (list :line-width box-width :color mantle))
      ;; Active tab face
      (set-face-attribute 'tab-line-tab-current nil
                          :foreground fg
                          :background bg
                          :height 1.0
                          :weight 'normal
                          :inherit nil
                          :box (list :line-width box-width :color bg))
      ;; Active tab face
      (set-face-attribute 'tab-line-tab nil
                          :foreground fg
                          :background bg
                          :height 1.0
                          :weight 'normal
                          :inherit nil
                          :box (list :line-width box-width :color bg))
      ;; Inactive tab face
      (set-face-attribute 'tab-line-tab-inactive nil
                          :foreground fg
                          :background mantle
                          :weight 'normal
                          :inherit nil
                          :height 1.0
                          :box (list :line-width box-width :color mantle))
      ;; Make special and alternate tabs use standard face inheritance
      (set-face-attribute 'tab-line-tab-special nil :inherit nil)
      (set-face-attribute 'tab-line-tab-inactive-alternate nil
                          :inherit 'tab-line-tab-active
                          :height 1.0
                          :box (list :line-width box-width :color mantle))
      ;; Highlight
      (set-face-attribute 'tab-line-highlight nil
                          :foreground fg
                          :background surface1
                          :weight 'normal
                          :inherit nil
                          :box (list :line-width box-width :color surface1))))
  ;; (face-spec-reset-face 'tab-line-tab-inactive-alternate)
  ;; (my/set-tab-theme)

  (defun my/tab-line-name-buffer (buffer &rest _buffers)
    "Create name for tab with padding and truncation.

If buffer name is shorter than `tab-line-tab-max-width' it gets
centered with spaces, otherwise it is truncated, to preserve
equal width for all tabs.  This function also tries to fit as
many tabs in window as possible, so if there are no room for tabs
with maximum width, it calculates new width for each tab and
truncates text if needed.  Minimal width can be set with
`tab-line-tab-min-width' variable."
    (with-current-buffer buffer
      (let* ((window-width (window-width (get-buffer-window)))
             (tab-amount (length (tab-line-tabs-window-buffers)))
             (window-max-tab-width (if (>= (* (+ tab-line-tab-max-width 3) tab-amount) window-width)
                                       (/ window-width tab-amount)
                                     tab-line-tab-max-width))
             (tab-width (- (cond ((> window-max-tab-width tab-line-tab-max-width)
                                  tab-line-tab-max-width)
                                 ((< window-max-tab-width tab-line-tab-min-width)
                                  tab-line-tab-min-width)
                                 (t window-max-tab-width))
                           3)) ;; compensation for ' x ' button
             (buffer-name (string-trim (buffer-name)))
             (name-width (length buffer-name)))
        (if (>= name-width tab-width)
            (concat  " " (truncate-string-to-width buffer-name (- tab-width 2)) "…")
          (let* ((padding (make-string (+ (/ (- tab-width name-width) 2) 1) ?\s))
                 (buffer-name (concat padding buffer-name)))
            (concat buffer-name (make-string (- tab-width (length buffer-name)) ?\s)))))))

  (defun tab-line-close-tab (&optional e)
    "Close the selected tab.

If tab is presented in another window, close the tab by using
`bury-buffer` function.  If tab is unique to all existing
windows, kill the buffer with `kill-buffer` function.  Lastly, if
no tabs left in the window, it is deleted with `delete-window`
function."
    (interactive "e")
    (let* ((posnp (event-start e))
           (window (posn-window posnp))
           (buffer (get-pos-property 1 'tab (car (posn-string posnp)))))
      (with-selected-window window
        (let ((tab-list (tab-line-tabs-window-buffers))
              (buffer-list (flatten-list
                            (seq-reduce (lambda (list window)
                                          (select-window window t)
                                          (cons (tab-line-tabs-window-buffers) list))
                                        (window-list) nil))))
          (select-window window)
          (if (> (seq-count (lambda (b) (eq b buffer)) buffer-list) 1)
              (progn
                (if (eq buffer (current-buffer))
                    (bury-buffer)
                  (set-window-prev-buffers window (assq-delete-all buffer (window-prev-buffers)))
                  (set-window-next-buffers window (delq buffer (window-next-buffers))))
                (unless (cdr tab-list)
                  (ignore-errors (delete-window window))))
            (and (kill-buffer buffer)
                 (unless (cdr tab-list)
                   (ignore-errors (delete-window window)))))))))

  (setq tab-line-close-button-show t
        tab-line-new-button-show nil
        tab-line-separator ""
        tab-line-tab-name-function #'my/tab-line-name-buffer
        tab-line-right-button (propertize (if (char-displayable-p ?▶) " ▶ " " > ")
                                          'keymap tab-line-right-map
                                          'mouse-face 'tab-line-highlight
                                          'help-echo "Click to scroll right")
        tab-line-left-button (propertize (if (char-displayable-p ?◀) " ◀ " " < ")
                                         'keymap tab-line-left-map
                                         'mouse-face 'tab-line-highlight
                                         'help-echo "Click to scroll left")
        tab-line-close-button (propertize (if (char-displayable-p ?×) " × " " x ")
                                          'keymap tab-line-tab-close-map
                                          'mouse-face 'tab-line-close-highlight
                                          'help-echo "Click to close tab"))

  ;;  (my/set-tab-theme)
  ;;(dolist (mode '(ediff-mode process-menu-mode term-mode vterm-mode))
  ;;(add-to-list 'tab-line-exclude-modes mode))
  (dolist (mode '(ediff-mode process-menu-mode))
    (add-to-list 'tab-line-exclude-modes mode))
  )

;;;; Persisent, isolated workspaces per tab
(use-package tabspaces
  :after (evil which-key)
  :ensure (:host github :repo "mclear-tools/tabspaces")
  :demand t
  :config
  (tabspaces-mode)
  ;; Setup which-key menu prefixes
  (which-key-add-key-based-replacements
    "SPC w" "workspaces"
    "SPC b" "buffers"
    "SPC f" "files/dirvish")
  ;; Evil normal state bindings
  (evil-define-key* 'normal 'global
    "gn" 'tabspaces-switch-next-workspace    ; Next workspace
    "gp" 'tabspaces-switch-prev-workspace    ; Previous workspace
    "gl" 'tabspaces-switch-last-workspace)   ; Last used workspace
  
  ;; Workspace management with leader
  (evil-define-key* 'normal 'global
    (kbd "<leader>ww") 'tabspaces-switch-workspace  
    (kbd "<leader>wk") 'tabspaces-kill-buffers-close-workspace
    (kbd "<leader>wr") 'tabspaces-remove-current-buffer)
  ;; Leader key bindings using evil-leader style
  ;; (evil-define-key 'normal 'global 
  ;;   (kbd "SPC wc") 'tabspaces-open-or-create-project-and-workspace
  ;;   (kbd "SPC ws") 'tabspaces-switch-or-create-workspace
  ;;   (kbd "SPC wd") 'tabspaces-close-workspace
  ;;   (kbd "SPC wk") 'tabspaces-kill-buffers-close-workspace
  ;;   ;; Buffer management within workspaces
  ;;   (kbd "SPC bb") 'tabspaces-switch-to-buffer
  ;;   (kbd "SPC br") 'tabspaces-remove-current-buffer
  ;;   (kbd "SPC bR") 'tabspaces-remove-selected-buffer
  ;;   (kbd "SPC bt") 'tabspaces-switch-buffer-and-tab
  ;;   (kbd "SPC bk") 'kill-current-buffer)
  
  ;; Configure workspace behavior
  (setq tabspaces-use-filtered-buffers-as-default t
        tabspaces-default-tab "main"
        tabspaces-remove-to-default t
        tabspaces-include-buffers '("*scratch*" "*Messages*")
        ;; Sessions
        tabspaces-session t
        tabspaces-session-auto-restore t))
;;;; Window
(use-package window
  :ensure nil
  ;;:hook
  ;;(run-window-configuration-change #'(lambda () (set-window-scroll-bars (minibuffer-window) nil nil)))
  :config
  (setq bidi-display-reordering  'left-to-right
        bidi-paragraph-direction 'nil
        fringes-outside-margins  t)
  (setq-default display-line-numbers-width 6)
  ;; minimal fringes
  (set-fringe-style 1)

  ;;(setq switch-to-buffer-obey-display-actions t)
  (setq split-height-threshold        nil
        split-width-threshold         200
        highlight-nonselected-windows nil
        auto-window-vscroll           nil
        fast-but-imprecise-scrolling  t
        ring-bell-function            #'ignore
        scroll-conservatively         101))
;;(setq pixel-scroll-precision-large-scroll-height 10))
;;;; Icons & ligatures
(use-package kind-icon)
(use-package nerd-icons)
(use-package nerd-icons-completion
  :ensure (:host github :repo "rainstormstudio/nerd-icons-completion")
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))
(use-package vscode-icon
  :ensure (:host github :repo "jojojames/vscode-icon-emacs" :wait t)
  :demand t)
;;(use-package all-the-icons-completion :config (all-the-icons-completion-mode))
(use-package ligature
  :config
  (ligature-set-ligatures 't '("www" "**" "***" "**/" "*>" "*/" "\\\\" "\\\\\\" "{-" "::"
                               ":::" ":=" "!!" "!=" "!==" "-}" "----" "-->" "->" "->>"
                               "-<" "-<<" "-~" "#{" "#[" "##" "###" "####" "#(" "#?" "#_"
                               "#_(" ".-" ".=" ".." "..<" "..." "?=" "??" ";;" "/*" "/**"
                               "/=" "/==" "/>" "//" "///" "&&" "||" "||=" "|=" "|>" "^=" "$>"
                               "++" "+++" "+>" "=:=" "==" "===" "==>" "=>" "=>>" "<="
                               "=<<" "=/=" ">-" ">=" ">=>" ">>" ">>-" ">>=" ">>>" "<*"
                               "<*>" "<|" "<|>" "<$" "<$>" "<!--" "<-" "<--" "<->" "<+"
                               "<+>" "<=" "<==" "<=>" "<=<" "<>" "<<" "<<-" "<<=" "<<<"
                               "<~" "<~~" "</" "</>" "~@" "~-" "~>" "~~" "~~>" "%%"))

  (global-ligature-mode 't))

;;;; Minimap
(use-package minimap
  :disabled
  :config
  ;; Toggle minimap visibility
  (defun toggle-minimap ()
    "Toggle minimap visibility."
    (interactive)
    (if (null (minimap-get-window))
        (minimap-create)
      (minimap-kill)))

  ;; Toggle minimap line highlighting
  (defun toggle-minimap-highlight-line ()
    "Toggle minimap line highlighting."
    (interactive)
    (setq minimap-highlight-line (not minimap-highlight-line))
    (if minimap-highlight-line
        (custom-set-faces
         '(minimap-current-line-face :background "#51AFEF" :group 'minimap))
      (custom-set-faces
       '(minimap-current-line-face
         ((((background dark)) (:background "#7F7F7F"))
          (t (:background "#ABABAB")))
         :group 'minimap))))

  ;; Minimap configuration
  (setq minimap-window-location 'right
        minimap-width-fraction 0.03
        minimap-minimum-width 11
        minimap-dedicated-window t
        minimap-highlight-line t
        minimap-enlarge-certain-faces t)

  ;; Keybindings (modify as needed)
  (global-set-key (kbd "C-c m") 'toggle-minimap)
  (global-set-key (kbd "C-c h") 'toggle-minimap-highlight-line)

  ;; Disable modeline in minimap buffer
  (add-hook 'minimap-sb-mode-hook 'hide-mode-line-mode)

  ;; Change colors of minimap

  ;; Set custom font for minimap (optional)
  (custom-set-faces
   '(minimap-font-face ((t (:family "BlockFont" :height 30)))))

  ;; Enable minimap for specific major modes
  ;;(setq minimap-major-modes '(prog-mode))
  ;;(setq minimap-major-modes nil)

  ;; Automatically enable minimap on startup (optional)
  ;; (add-hook 'after-init-hook 'minimap-mode)

  ;;(provide 'minimap-config)
  )
;;;; Highlight code in EWW
(use-package shr-tag-pre-highlight
  :disabled
  ;;  :after shr
  :config
  (add-to-list 'shr-external-rendering-functions
               '(pre . shr-tag-pre-highlight))
  (with-eval-after-load 'eww
    (advice-add 'eww-display-html :around
                'eww-display-html--override-shr-external-rendering-functions)))


;;;; guide bars
(use-package indent-bars
  :ensure (:host github :repo "jdtsmith/indent-bars")
  :custom
  (indent-bars-prefer-character t)  ; Use character-based bars instead of stipples
  (indent-bars-no-stipple-char ?│)  ; Use this character for the bars
  (indent-bars-display-on-blank-lines t)  ; Show bars on blank lines
  (indent-bars-treesit-support t)  ; Enable treesitter support if available
  (indent-bars-spacing-override nil)  ; Let modes determine their own spacing
  (indent-bars-pattern ".")  ; Simple pattern that works well with characters
  :hook
  ((python-ts-mode python-mode) . (lambda ()
                                    (setq-local indent-bars-no-descend-lists t)
                                    (indent-bars-mode)))
  (emacs-lisp-mode . (lambda ()
                       (setq-local indent-bars-no-descend-lists nil)
                       (indent-bars-mode)))
  (yaml-mode . indent-bars-mode))

;;; mac specific ---- TODO: needed anymore w/ emacs version 30+? see emacs-plus
;; (use-package exec-path-from-shell
;;   :config
;;   (setq mac-command-modifier 'meta)
;;   (global-set-key [(hyper a)] 'mark-whole-buffer)
;;   (global-set-key [(hyper v)] 'yank)
;;   (global-set-key [(hyper c)] 'kill-ring-save)
;;   (global-set-key [(hyper s)] 'save-buffer)
;;   (global-set-key [(hyper l)] 'goto-line)
;;   (global-set-key [(hyper w)]
;;                   (lambda () (interactive) (delete-window)))
;;   (global-set-key [(hyper z)] 'undo)
;;   (exec-path-from-shell-initialize))
;;; Programming & IDEs
;;;; graciously handle switching between tab or space preferred files
(use-package dtrt-indent :config (dtrt-indent-global-mode 1))

;;;; apheleia ---- format-on-save
(use-package apheleia
  :ensure t
  :config (apheleia-global-mode))

;;;; treesit-auto ---- prompt-install grammars
(use-package treesit-auto
  :ensure t :defer t
  :config
  (setq treesit-auto-install 'prompt)
  (global-treesit-auto-mode))

;;;; colorful-mode ---- highlight color literals
(use-package colorful-mode
  :ensure t
  :config (global-colorful-mode))

;;;; TODO fix treesitter
(setq treesit-font-lock-level 4)
(setq treesit-language-source-alist
      '((bash "https://github.com/tree-sitter/tree-sitter-bash")
        (cmake "https://github.com/uyha/tree-sitter-cmake")
        (css "https://github.com/tree-sitter/tree-sitter-css")
        (elisp "https://github.com/Wilfred/tree-sitter-elisp")
        (go "https://github.com/tree-sitter/tree-sitter-go")
        (html "https://github.com/tree-sitter/tree-sitter-html")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
        (json "https://github.com/tree-sitter/tree-sitter-json")
        (make "https://github.com/alemuller/tree-sitter-make")
        (markdown "https://github.com/tree-sitter-grammars/tree-sitter-markdown" "split_parser" "tree-sitter-markdown/src")
        (markdown-inline "https://github.com/tree-sitter-grammars/tree-sitter-markdown" "split_parser" "tree-sitter-markdown-inline/src")
        (python "https://github.com/tree-sitter/tree-sitter-python")
        (toml "https://github.com/tree-sitter/tree-sitter-toml")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
        (yaml "https://github.com/ikatyang/tree-sitter-yaml")))

;;(mapc #'treesit-install-language-grammar (mapcar #'car treesit-language-source-alist))

(use-package tree-sitter-langs :ensure t)
;;;; EmacsLisp
;;;;; scan for unbalanced parens every save
(use-package lisp
  :ensure nil
  :hook
  (after-save . check-parens))

;;;;; highlight defined objects in buffers
(use-package highlight-defined
  :custom
  (highlight-defined-face-use-itself t)
  :hook
  (help-mode . highlight-defined-mode)
  (emacs-lisp-mode . highlight-defined-mode))

(use-package highlight-quoted
  :hook
  (emacs-lisp-mode . highlight-quoted-mode))

(use-package highlight-sexp
  ;; :ensure (:host github :repo "daimrod/highlight-sexp")
  :disabled
  :hook
  (clojure-mode . highlight-sexp-mode)
  (emacs-lisp-mode . highlight-sexp-mode)
  (lisp-mode . highlight-sexp-mode))

(use-package ipretty
  :disabled
  :config
  (ipretty-mode 1))

(use-package rainbow-delimiters
  :hook
  (emacs-lisp-mode . rainbow-delimiters-mode))

(use-package nameless
  :disabled
  :hook
  (emacs-lisp-mode .  nameless-mode)
  :custom
  (nameless-global-aliases '())
  (nameless-private-prefix t))

;;;;; provide input and output to explore functions as an answer from emacs
(use-package suggest
  :defer 5)

;;;;; inline evaluation overlay
(use-package eros
  :hook
  (emacs-lisp-mode . eros-mode))

;;;;; elisp insight (cursor-sensor doc)
(use-package semel
  :ensure (:host github :repo "eshelyaron/semel")
  :defer t
  :hook ((emacs-lisp-mode . semel-mode)
         (emacs-lisp-mode . cursor-sensor-mode)))

;;;;; eval flashing
(use-package eval-sexp-fu :ensure t :defer t)
(use-package cider-eval-sexp-fu
  :ensure t :defer t :after (cider eval-sexp-fu)
  :config (require 'cider-eval-sexp-fu))

;;;;; Scheme / Guile / Hoot
(use-package geiser :ensure t :defer t)
(use-package geiser-guile :ensure t :defer t)
;; (use-package geiser-hoot
;;   :ensure nil
;;   :commands (run-hoot geiser-hoot-connect connect-to-hoot)
;;   :init
;;   (with-eval-after-load 'geiser
;;     (require 'geiser-hoot))
;;   :config
;;   (setq geiser-hoot-scheme-dir "~/git/guile/geiser-hoot-src"))

;;;; Markdown
(setq eglot-extend-to-xref t)
(use-package markdown-ts-mode
  :mode ("\\.md\\'" . markdown-ts-mode)
  :defer 10)

;;;; rust
(use-package rustic
  :init
  (setq rustic-cargo-bin "cargo"))
;;  (push 'rustic-clippy flycheck-checkers))

;;;; go
(use-package go-mode
  :hook (go-mode . tree-sitter-hl-mode))

;;;; lua
(use-package lua-mode
  :hook (lua-mode . tree-sitter-hl-mode))

;;;; fennel
(use-package fennel-mode
  :config
  (defun remove-newlines-in-region ()
    "Remove all newlines in the region."
    (interactive)
    (save-restriction
      (narrow-to-region (point) (mark))
      (goto-char (point-min))
      (while (search-forward "\n" nil t) (replace-match "" nil t))))
  (defun love2d-collapse-and-eval-defun ()
    "Collapse region, and send to love2d REPL."
    (interactive)
    (remove-newlines-in-region)
    (lisp-eval-defun))
  :bind ((:map fennel-mode-map
               ("C-c C-e" . love2d-collapse-and-eval-defun)
               ("C-c C-r" . remove-newlines-in-region))))
;;;; terraform
(use-package terraform-mode
  :hook (terraform-mode . tree-sitter-hl-mode))
;;;; clojure
(use-package cider)

;;(require 'tree-sitter-langs)
;;(require 'treesit)
;;(global-tree-sitter-mode)
;;(add-hook 'sh-mode-hook (lambda () (tree-sitter-mode)(tree-sitter-hl-mode 1)))
;;(add-hook 'prog-mode-hook #'tree-sitter-hl-mode))
;;(add-hook 'prog-mode-hook #'turn-on-tree-sitter-mode)
;;(add-hook 'sh-set-shell-hook #'tree-sitter-hl-mode)
;;(add-hook 'tree-sitter-after-on-hook #'tree-sitter-hl-mode)
;;(add-hook 'tree-sitter-after-first-parse-hook #'tree-sitter-hl-mode)
;;(add-hook 'tree-sitter-after-first-parse-hook #'tree-sitter-hl-mode)
;;(if (treesit-available-p)
;;    (progn
;;      (message "Tree-Sitter is available")
;;      ;; Shell script files
;;      (if (treesit-language-available-p 'sh)
;;          (add-to-list 'auto-mode-alist '("\\.sh\\'" . bash-ts-mode)))))
;;;; shell script
(use-package shell
  :ensure nil
  :hook (shell-mode . tree-sitter-hl-mode))

;; (use-package js
;;   :mode "\\.js'"
;;   :config
;;   ;;  (setq js-indent-level --indent-width)
;;   :hook
;;   (((js-mode
;;      typescript-mode) . subword-mode)))

;;(use-package typescript-mode
;;  :mode "\\.ts?\\'"
;;  :hook ((typescript-mode . subword-mode))
;;  :config
;;  (setq-default typescript-indent-level --indent-width))
;;;; css
(use-package css
  :ensure nil
  :mode "\\.s?css\\'")
;;;; ts/js
(use-package web-mode
  :mode (("\\.html?\\'" . web-mode))
  :config
  ;;  (setq web-mode-markup-indent-offset --indent-width)
  ;;  (setq web-mode-code-indent-offset --indent-width)
  ;;  (setq web-mode-css-indent-offset --indent-width)
  (setq web-mode-content-types-alist '(("jsx" . "\\.js[x]?\\'"))))
;;;; python
(use-package python
  :ensure nil  ; built-in
  :hook ((python-mode . eglot-ensure)
         (python-mode . flymake-mode)))

(use-package flymake-collection
  :after flymake
  :config
  (push '(python-mode
          flymake-collection-pycodestyle
          flymake-collection-mypy) 
        flymake-collection-config)
  (flymake-collection-hook-setup))
;;;; common lisp
;; Common Lisp Development Setup
(use-package sly
  :ensure nil
  :config
  ;; Configure SLY
  ;; (setq sly-complete-symbol-function 'sly-flex-completions)
  (setq sly-net-coding-system 'utf-8-unix)

  ;; (setq sly-lisp-implementations `((sbcl ("/home/bfh/.guix-home/profile/bin/sbcl"))))
  (setq sly-lisp-implementations
        `((sbcl-trial-guix ("/home/bfh/.guix-home/profile/bin/sbcl" "--dynamic-space-size" "2000"))
          (sbcl-guix ("/home/bfh/.guix-home/profile/bin/sbcl"))))
  
  ;; Enable ParEdit mode for Lisp modes
  ;; ;; (add-hook 'sly-mode-hook 'enable-paredit-mode)
  ;; (add-hook 'sly-mrepl-mode-hook 'enable-paredit-mode)
  
  ;; Enable Rainbow delimiters
  ;; (add-hook 'sly-mode-hook 'rainbow-delimiters-mode)
  ;; (add-hook 'sly-mrepl-mode-hook 'rainbow-delimiters-mode)
  
  ;; Company mode integration
  ;;  (add-hook 'sly-mode-hook 'company-mode)
  ;; (add-hook 'sly-mrepl-mode-hook 'company-mode)
  )

;; SLY-ASDF configuration
(use-package sly-asdf
  :ensure nil
  :after sly)

;; SLY overlay eval + leader bindings
(use-package sly-overlay
  :ensure t
  :defer t :after (sly evil which-key)
  :config
  (which-key-add-key-based-replacements "SPC l" "sly-eval")
  (evil-define-key 'normal sly-mode-map
    (kbd "<leader>ll") 'sly-overlay-eval-defun
    (kbd "<leader>lr") 'sly-overlay-eval-region
    (kbd "<leader>lp") 'sly-overlay-eval-print-last-expression
    (kbd "C-c C-c") 'sly-overlay-eval-defun
    (kbd "C-c C-r") 'sly-overlay-eval-region
    (kbd "C-c C-p") 'sly-overlay-eval-print-last-expression))

;; Additional useful packages for Lisp development
(use-package lispy
  :ensure nil
  :init
  (setq lispy-key-theme '(lispy c-digits))
  :hook ((emacs-lisp-mode lisp-mode scheme-mode clojure-mode fennel-mode)
         . lispy-mode))

(use-package lispyville
  :ensure nil
  :after (evil lispy transient)
  :hook ((emacs-lisp-mode lisp-mode scheme-mode
                          clojure-mode clojurescript-mode fennel-mode)
         . lispyville-mode)
  
  :init
  (setq lispyville-key-theme
        '((operators normal visual)
          c-w
          c-u
          prettify
          text-objects
          (atom-movement normal motion visual)
          (additional-movement normal motion visual)
          slurp/barf-lispy
          additional
          additional-insert
          additional-wrap
          commentary))
  :config
  (lispyville-set-key-theme)

  (evil-define-key '(normal motion visual) lispyville-mode-map
    "J" #'lispyville-up-list
    "K" #'lispyville-next-opening)

  (transient-define-prefix bfh/lispyville-menu ()
    "Lispyville structural editing."
    [["Move"
      ("H"   "prev sibling"    lispyville-backward-sexp        :transient t)
      ("L"   "next sibling"    lispyville-forward-sexp         :transient t)
      ("J"   "out (parent)"    lispyville-up-list              :transient t)
      ("K"   "in (child)"      lispyville-next-opening         :transient t)
      ("M-h" "defun top"       lispyville-beginning-of-defun   :transient t)
      ("M-l" "defun end"       lispyville-end-of-defun         :transient t)]
     ["Jump"
      ("("   "parent open"     lispyville-backward-up-list     :transient t)
      (")"   "parent close"    lispyville-up-list              :transient t)
      ("{"   "next open"       lispyville-next-opening         :transient t)
      ("}"   "prev close"      lispyville-previous-closing     :transient t)
      ("["   "prev open"       lispyville-previous-opening     :transient t)
      ("]"   "next close"      lispyville-next-closing         :transient t)]
     ["Reshape"
      (">"   "slurp"           lispyville-slurp                :transient t)
      ("<"   "barf"            lispyville-barf                 :transient t)
      ("M-j" "drag fwd"        lispyville-drag-forward         :transient t)
      ("M-k" "drag bwd"        lispyville-drag-backward        :transient t)
      ("M-r" "raise sexp"      lispy-raise-sexp                :transient t)
      ("M-R" "raise list"      lispyville-raise-list           :transient t)
      ("M-s" "splice"          lispy-splice                    :transient t)
      ("M-S" "split"           lispy-split                     :transient t)
      ("M-J" "join"            lispy-join                      :transient t)
      ("M-t" "transpose"       transpose-sexps                 :transient t)
      ("M-v" "convolute"       lispy-convolute-sexp            :transient t)]
     ["Wrap / Insert / Comment"
      ("M-(" "wrap ()"         lispyville-wrap-round)
      ("M-[" "wrap []"         lispyville-wrap-brackets)
      ("M-{" "wrap {}"         lispyville-wrap-braces)
      ("M-i" "insert list beg" lispyville-insert-at-beginning-of-list)
      ("M-a" "insert list end" lispyville-insert-at-end-of-list)
      ("M-o" "open below"      lispyville-open-below-list)
      ("M-O" "open above"      lispyville-open-above-list)
      ("c"   "comment toggle"  lispyville-comment-or-uncomment :transient t)
      ("y"   "comment + clone" lispyville-comment-and-clone-dwim :transient t)]])

  (evil-define-key 'normal lispyville-mode-map
    (kbd "gh") #'bfh/lispyville-menu))

;; Set up Common Lisp specific configurations
(with-eval-after-load 'common-lisp-mode
  (setq common-lisp-style-default "modern")
  (add-hook 'common-lisp-mode-hook #'show-paren-mode))
;; (use-package sly
;;   :hook ((lisp-mode . sly-mode))
;;   :config
;;   (setq inferior-lisp-program "ros -Q run")
;;   (setq org-babel-lisp-eval-fn #'sly-eval)
;;   (setq inferior-lisp-program "sbcl"))    
;; (use-package sly-asdf
;;   :disabled 
;;   :config
;;   (add-to-list 'sly-contribs 'sly-asdf 'append))
;; (setq inferior-lisp-program "ros -Q run")
;;;; nix
(use-package nix-mode
  :defer t
  :mode "\\.nix\\'")

;;;; ansible
(use-package ansible
  :defer t
  :hook (yaml-mode-hook . ansible))

;;;; eglot (lsp)
(use-package eglot
  :init
  ;; Performance settings
  (setq read-process-output-max (* 1024 1024)) ;; 1mb
  (setq eglot-sync-connect nil)
  (setq eglot-connect-timeout 10)

  ;; Configure project detection for Go modules
  (require 'project)
  (defun project-find-go-module (dir)
    (when-let ((root (locate-dominating-file dir "go.mod")))
      (cons 'go-module root)))
  
  (cl-defmethod project-root ((project (head go-module)))
    (cdr project))
  
  (add-hook 'project-find-functions #'project-find-go-module)

  ;; Gopls specific settings
  (setq-default eglot-workspace-configuration
                '((:gopls . ((staticcheck . t)
                             (matcher . "CaseSensitive")))))

  :config
  ;; Auto-format before save
  (defun eglot-format-buffer-before-save ()
    (add-hook 'before-save-hook #'eglot-format-buffer -10 t))

  ;; Organize imports before save
  (defun eglot-organize-imports-before-save ()
    (add-hook 'before-save-hook
              (lambda ()
                (call-interactively 'eglot-code-action-organize-imports))
              nil t))

  :hook
  ((go-mode . eglot-ensure)
   (go-mode . eglot-format-buffer-before-save)
   (go-mode . eglot-organize-imports-before-save)))
;;;; jupyter notebook
(use-package jupyter
  :disabled
  :config
  (setq jupyter-eval-use-overlays t)
  (setq jupyter-repl-echo-eval-p t))
;;; Notes/Docs
;;;; TODO: add marksmanlsp/markdown
(use-package org
  :ensure nil
  :mode ("\\.org\\'" . org-mode)
  :config
  (setq org-directory "~/.emacs.d/org")
  (setq org-agenda-files '("~/.emacs.d/org"))
  (setq org-default-notes-file (concat org-directory "/.org"))
  (setq org-refile-targets '((org-agenda-files :maxlevel . 3)))
  (setq org-agenda-restore-windows-after-quit t)   
  (setq org-hide-emphasis-markers t)              
  (setq org-catch-invisible-edits 'show-and-error) 
  (setq org-startup-indented t)           

  (setq org-edit-src-content-indentation 0
        org-src-tab-acts-natively t
        org-src-fontify-natively t)

  (setq org-confirm-babel-evaluate nil)
  (org-babel-do-load-languages 'org-babel-load-languages
                               '((shell . t)
                                 (emacs-lisp . t)
                                 ;;              (mermaid . t)
                                 (clojure . t)))
  (setq org-babel-clojure-backend 'cider)

  (define-key global-map "\C-ca" 'org-agenda)
  (define-key global-map "\C-cc" 'org-capture)
  (define-key global-map "\C-cr" 'org-refile)

  (setq org-todo-keywords
        '((sequence "TODO(t!)" "IN-PROGRESS(p!)" "WAITING(w@/!)" "|" "DONE(d!)")
          (sequence "|" "CANCELLED(c@/!)" "DELEGATED(e@/!)" "SOMEDAY(s@/!)")))

  (setq org-capture-templates
        '(("t" "Todo" entry (file "~/.emacs.d/org/Tasks.org")
           "* TODO %?" :empty-lines 1)
          ("j" "Journal" entry (file+olp+datetree "~/.emacs.d/org/Journal.org")
           "* %?\nEntered on: %<%r>" :tree week)
          ("h" "Habit" entry (file "~/.emacs.d/org/Habits.org")
           "* TODO %?\nSCHEDULED: %(format-time-string \"%<<%Y-%m-%d %a .+2d/3d>>\")\n:PROPERTIES:\n:STYLE: habit\n:END:")))

  (setq org-tag-persistent-alist '(("Leisure" . ?l)("Moderate" . ?m) ("Urgent" . ?u)
                                   (:newline . nil)
                                   ("Work" . ?w) ("Personal" . ?p)
                                   (:newline . nil)
                                   ("Practice" . ?P) ("Read" . ?r))))
;;; Basic folding and org everywhere else in normal comments
(use-package outli
  :ensure (:host github :repo "jdtsmith/outli")
  :custom
  (outli-heading-config
   '((python-mode "#" ?# t)
     (ruby-mode "#" ?# t)
     (rust-mode "//" ?/ t)
     (js-mode "//" ?/ t)
     (typescript-mode "//" ?/ t)
     (c++-mode "//" ?/ t)
     (emacs-lisp-mode ";;" ?\; t)
     (lisp-mode ";;" ?\; t)
     (clojure-mode ";;" ?\; t)
     ;; Default for other modes
     (t (let* ((c (or comment-start "#"))
               (space (unless (eq (aref c (1- (length c))) ?\s) " ")))
          (concat c space))
        ?*)))
  :bind (:map outli-mode-map 
              ("C-c C-p" . (lambda () (interactive) (outline-back-to-heading))))
  :hook ((prog-mode text-mode) . outli-mode))


;;; Multimedia


;;;; ready-player ---- simple 
(use-package ready-player
  :after transient
  :defer t
  :config
  (ready-player-mode +1))
;;;; emms 
(use-package emms
  :init
  (add-hook 'emms-player-started-hook 'emms-show)
  (setq emms-show-format "Playing: %s")
  :config
  (emms-all)
  (setq emms-player-list '(emms-player-mpv))
  ;; look into tinytag for metadata extraction
  ;;(setq emms-browser-covers 'emms-browser-cache-thumbnail-async)
  (setq emms-player-mpv-parameters '("--quiet" "--really-quiet" "--no-config" "--save-position-on-quit" "--no-audio-display" )) ;; please really never ever under any circumstance ever show yourself
  (setq emms-source-file-default-directory "~/Downloads/music"))
;;;; ytdl
(use-package ytdl
  :disabled
  :config
  (setq ytdl-music-folder "~/music"))

;;; Shells and terminals
(use-package bash-completion
  :disabled
  :config
  (autoload 'bash-completion-dynamic-complete
    "bash-completion"
    "BASH completion hook")
  (add-hook 'shell-dynamic-complete-functions
            'bash-completion-dynamic-complete))


;;; Files and directory management
(use-package dirvish
  :ensure t
  :after transient
  :init
  (dirvish-override-dired-mode)
  :custom
  ;; Quick access locations - customize these paths
  (dirvish-quick-access-entries
   '(("h" "~/"                "Home")
     ("d" "~/Downloads/"      "Downloads")
     ("p" "~/Projects/"       "Projects")
     ("c" "~/.config/"        "Config")))
  ;; How to display file attributes in mode-line
  ;; (dirvish-mode-line-format
  ;;  '(:left (sort symlink) :right (omit yank index)))
  ;; File attributes to show
  (dirvish-attributes
   '(nerd-icons        ; File icons
     file-size            ; File size
     file-time           ; File mtime
     subtree-state        ; Subtree indicator
     collapse            ; Collapse unique nested paths
     vc-state            ; Version control status
     git-msg))           ; Git commit message
  (dirvish-side-width 35)
  :config
  ;; Enable useful features
  (dirvish-peek-mode)              ; Preview files in minibuffer
  (dirvish-side-follow-mode)       ; Similar to treemacs-follow-mode
  (setq dirvish-subtree-state-style 'nerd)

  ;; Default to moving to trash instead of deleting
  (setq delete-by-moving-to-trash t)
  
  ;; Better ls switches with human readable sizes
  ;; (setq dired-listing-switches
  ;;       "-l --almost-all --human-readable --group-directories-first --no-group")

  ;; Improved bulk rename support
  (setq wdired-allow-to-change-permissions t) ; Allow permission editing
  (setq wdired-create-parent-directories t)   ; Create parent dirs when needed
  
  ;; Function to enter wdired for bulk renaming
  (defun my/dirvish-bulk-rename ()
    "Enter wdired mode for bulk renaming."
    (interactive)
    (wdired-change-to-wdired-mode))

  :bind
  (("C-c f" . dirvish-fd)          ; Quick file search using fd
   :map dirvish-mode-map
   ;; Basic navigation and operations
   ("/"   . dirvish-narrow)        ; Live-narrow files
   ("a"   . dirvish-quick-access)  ; Jump to frequent dirs
   ("f"   . dirvish-file-info-menu)
   ("y"   . dirvish-yank-menu)     ; Copy/move menu
   ("R"   . my/dirvish-bulk-rename) ; Enter bulk rename mode
   
   ;; History navigation
   ("^"   . dirvish-history-last)
   ("h"   . dirvish-history-jump)
   ("M-f" . dirvish-history-go-forward)
   ("M-b" . dirvish-history-go-backward)
   
   ;; Tree and layout operations
   ("TAB" . dirvish-subtree-toggle)
   ("M-t" . dirvish-layout-toggle)
   
   ;; Sorting and filtering
   ("s"   . dirvish-quicksort)
   ("M-l" . dirvish-ls-switches-menu)
   ("M-m" . dirvish-mark-menu)
   ("M-s" . dirvish-setup-menu)
   ("M-e" . dirvish-emerge-menu)
   
   ;; Advanced features
   ("v"   . dirvish-vc-menu)       ; Version control menu
   ("M-j" . dirvish-fd-jump)))     ; Jump using fd


;;;; FIX ME

(require 'wdired)
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
;;     ("TAB" . dired-subtree-toggle)
;;     ("<C-tab>" . dired-subtree-cycle)
;;     ("<S-iso-lefttab>" . dired-subtree-remove))

;; Dired git info
;;(setq dgi-commit-message-format "%h\t%s\t%cr")
;;(bind-keys :package dired-git-info :map dired-mode-map
;;     (")" . dired-git-info-mode))


(setq vterm-max-scrollback 100000)

;;; AI / LLM
(use-package gptel
  :ensure t :defer t
  :config
  (gptel-make-anthropic "Claude" :stream t :key 'gptel-api-key-from-auth-source)
  (gptel-make-gemini "Gemini" :stream t :key 'gptel-api-key-from-auth-source)
  (gptel-make-openai "ChatGPT" :stream t :key 'gptel-api-key-from-auth-source)
  (setq gptel-default-mode 'org-mode
        gptel-model 'gemini-2.0-flash
        gptel-stream t
        gptel-expert-commands t
        gptel-include-reasoning nil
        gptel-use-tools t
        gptel-track-response t
        gptel-track-media t
        gptel--debug nil)
  (require 'gptel-curl)
  (require 'gptel-transient)
  (require 'gptel-integrations)
  (add-hook 'gptel-post-stream-hook 'gptel-auto-scroll)
  (add-hook 'gptel-post-response-functions 'gptel-end-of-response)
  (require 'gptel-tools)
  :bind (("C-c g s" . gptel-send)
         ("C-c g g" . gptel)
         ("C-c g m" . gptel-menu)
         ("C-c g r" . gptel-rewrite)
         ("C-c g a" . gptel-add)
         ("C-c g f" . gptel-add-file)))

(use-package mcp
  :ensure (mcp :host github :repo "lizqwerscott/mcp.el" :files (:defaults "*.el"))
  :defer t :after gptel
  :custom
  (mcp-hub-servers
   '(("filesystem" . (:command "npx" :args ("-y" "@modelcontextprotocol/server-filesystem" "~/")))
     ("mcp-server-text-editor" . (:command "npx" :args ("-y" "mcp-server-text-editor")))
     ("memory" . (:command "npx" :args ("-y" "@modelcontextprotocol/server-memory")))
     ("sequential-thinking" . (:command "npx" :args ("-y" "@modelcontextprotocol/server-sequential-thinking")))))
  :config (require 'mcp-hub))




;;; My commands
(defun sudo-file-name (filename &optional wildcards)
  "Edit file with sudo"
  (interactive
   (find-file-read-args "(Sudo) Find file: "
                        (confirm-nonexistent-file-or-buffer)))
  (let ((value (find-file-noselect
                (concat "/sudo::" filename) nil nil wildcards)))
    (if (listp value)
        (mapcar 'pop-to-buffer-same-window (nreverse value))
      (pop-to-buffer-same-window value))))

(defun display-ansi-colors ()
  "Take a region and render ansi encodings as their proper color."
  (interactive)
  (ansi-color-apply-on-region (point-min) (point-max)))

(defun my-wrap-string (text width)
  "Insert an Org‑line break marker (a space followed by \\) every WIDTH characters in TEXT.
Returns the wrapped text as a string."
  (let ((result "")
        (pos 0)
        (len (length text)))
    (while (< pos len)
      (let ((end (min len (+ pos width))))
        (setq result (concat result (substring text pos end)))
        (when (< end len)
          ;; Append the Org cell break marker followed by a newline.
          (setq result (concat result " \\\n")))
        (setq pos end)))
    result))

(defun my-csv-to-org-table (file &optional wrap-width)
  "Read a CSV file FILE (assumed to have two columns: timestamp and message)
and return an Org‑mode table as a string.
For the message column, insert an Org‑line break (\"\\\") every WRAP-WIDTH characters.
If WRAP-WIDTH is nil, it defaults to 80."
  (interactive "fCSV file: \nnWrap width (default 80): ")
  (unless wrap-width (setq wrap-width 80))
  (with-temp-buffer
    (insert-file-contents file)
    (let* ((lines (split-string (buffer-string) "\n" t))
           (table-lines
            (mapcar
             (lambda (line)
               (let* ((fields (split-string line "," t " *"))
                      (timestamp (nth 0 fields))
                      (message (nth 1 fields)))
                 (if (or (not timestamp) (not message))
                     (concat "| " line " |")
                   (let ((wrapped-msg (my-wrap-string message wrap-width)))
                     (format "| %s | %s |" timestamp wrapped-msg)))))
             lines)))
      (with-temp-buffer
        ;; Optionally, insert a header row:
        (insert "| timestamp | message |\n")
        (insert "|-----------+---------|\n")
        (insert (mapconcat 'identity table-lines "\n"))
        (org-table-align)
        (buffer-string)))))

;; To use this function:
;; 1. Evaluate the code above (e.g. paste it into your *scratch* buffer and do C-x C-e at the end of each defun).
;; 2. Run M-x my-csv-to-org-table, supply your CSV file and wrap width (e.g. 80).
;; 3. The function returns an Org table as a string; you can copy–paste that into your Org file.
(defun my-csv-to-org-table-insert (file &optional wrap-width)
  "Import FILE and insert an Org table with wrapped messages into the current buffer.
Assumes the CSV has two columns: timestamp and message.
WRAP-WIDTH defaults to 80 if not provided."
  (interactive "fCSV file: \nnWrap width (default 80): ")
  (unless wrap-width (setq wrap-width 80))
  (let ((table (my-csv-to-org-table file wrap-width)))
    (insert table)))

(defun list-project-scm-files-with-contents ()
  (interactive)
  (let* ((files (seq-filter (lambda (f) 
                              (and 
                               (not (string-match-p "~$" f))
                               (string-match-p "\\.scm$" f)))
                            (project-files (project-current))))
         (buf (get-buffer-create "*Project SCM Files*")))
    (with-current-buffer buf
      (org-mode)
      (erase-buffer)
      (dolist (file files)
        (insert (format "* %s\n" file))
        (when (file-readable-p file)
          (let ((contents (with-temp-buffer
                            (insert-file-contents file)
                            (buffer-string))))
            (insert contents)
            (unless (string-suffix-p "\n\n" contents)
              (insert "\n\n")))))
      (goto-char (point-min)))
    (switch-to-buffer buf)))
;;; Experiments
;;(require 'vc)
;;(require 'flycheck)
;;(require 'cider)

;; (defgroup modern-status-bar nil
;;   "Modern status bar using tab-bar-mode."
;;   :prefix "modern-status-bar-"
;;   :group 'convenience)

;; (defface modern-status-bar
;;   '((t (:inherit default
;;       ;;        :family "Arial"  ; or any other proportional font you prefer
;;       :height 110
;;       :foreground "#E0E0E0"
;;       :background "#404040"
;;       :box (:line-width (24 . 8) :color "#404040" :style flat-button))))
;;   "Face for the modern status bar."
;;   :group 'modern-status-bar)

;; (defcustom modern-status-bar-height 220
;;   "Height of the modern status bar in pixels."
;;   :type 'integer
;;   :group 'modern-status-bar)

;; (setq modern-status-bar-format
;;       '("%e"
;;         (:eval (when (and vc-mode buffer-file-name)
;;                  (let ((backend (vc-backend buffer-file-name)))
;;                    (when backend
;;                      (format " [%s:%s]"
;;                              (symbol-name backend)
;;                              (vc-state buffer-file-name backend))))))
;;         (:eval (when (bound-and-true-p flycheck-mode)
;;                  (let* ((count (flycheck-count-errors flycheck-current-errors))
;;                         (errors (flycheck-error-count-for-kind 'error))
;;                         (warnings (flycheck-error-count-for-kind 'warning)))
;;                    (if (or errors warnings)
;;                        (format " FlyC:[%s/%s]" (or errors 0) (or warnings 0))
;;                      " FlyC:✓"))))
;;         (:eval (when (bound-and-true-p cider-mode)
;;                  (format " REPL:%s" (cider--modeline-info))))
;;         " %" mode-name
;;  ;;        (:eval " L%l:C%c")
;;         " %Z"
;;         (:eval (when (bound-and-true-p evil-mode)
;;                  (let ((state (symbol-name evil-state)))
;;                    (propertize (format " -- %s --" state)
;;                                'face (cond ((eq evil-state 'normal) '(:foreground "green"))
;;                                            ((eq evil-state 'insert) '(:foreground "red"))
;;                                            ((eq evil-state 'visual) '(:foreground "orange"))
;;                                            (t '(:foreground "purple")))))))
;;         (:eval (if (buffer-modified-p) " [*]" " [-]"))
;;         (:eval (propertize " " 'display '(space :align-to (- right 10))))
;;         (:eval (format-time-string "%H:%M"))))

;; (defun modern-status-bar-format ()
;;   "Format the modern status bar."
;;   (let ((status-string (format-mode-line modern-status-bar-format)))
;;     `((global-mode-line menu-item ,status-string ignore))))

;; (define-minor-mode modern-status-bar-mode
;;   "Toggle the modern status bar."
;;   :global t
;;   :lighter " MSB"
;;   :group 'modern-status-bar
;;   (if modern-status-bar-mode
;;       (progn
;;         (setq-default mode-line-format nil)
;;         (setq tab-bar-format '(modern-status-bar-format))
;;         (set-face-attribute 'tab-bar nil
;;                             :inherit 'modern-status-bar
;;                             ;;family (face-attribute 'modern-status-bar :family)
;;                             :height modern-status-bar-height
;;                             :foreground (face-attribute 'modern-status-bar :foreground)
;;                             :background (face-attribute 'modern-status-bar :background)
;;                             :box (face-attribute 'modern-status-bar :box))
;;         (tab-bar-mode 1))
;;     (setq-default mode-line-format (default-value 'mode-line-format))
;;     (setq tab-bar-format '(tab-bar-format-tabs tab-bar-format-add-tab))
;;     (tab-bar-mode -1))
;;   (force-mode-line-update t))

;; ;;(provide 'modern-status-bar)
;; (setopt modern-status-bar-height (* (line-pixel-height) 8))
;; (modern-status-bar-mode 1)

;; ;;; Create a thin border around buffers
;; Box mode configuration
(defvar-local nano-box-cookies nil
  "Cookies to store local face modifications")

(defvar-local nano-box-state nil
  "State of the box around buffer")

(defvar-local nano-box-mode-line-format nil
  "Store original mode-line format")

(defun nano-modeline-element-window-spacing ()
  "Return conditional spacing"
  (let ((mode-line-format nil))
    (if (or (window-in-direction 'down)
            isearch-mode)
        (propertize " " 'face '(:height 80))
      (propertize " " 'face '(:height 10)))))

(defun nano-box-on ()
  "Install a box around current buffer using fringes, header line and mode line"
  (interactive)
  (setq-local nano-box-mode-line-format mode-line-format)
  (setq nano-box-state t
	    mode-line-format '(:eval (nano-modeline-element-window-spacing))
	    overline-margin 1
	    fringes-outside-margins t
	    left-margin-width 1
	    right-margin-width 1
	    left-fringe-width 1
	    right-fringe-width 1)
  
  (mapc #'face-remap-remove-relative nano-box-cookies)
  
  (let* ((fg-color (face-foreground 'default))
	     (bg-color (face-background 'default)))
    (setq nano-box-cookies
	      (list 
	       (face-remap-add-relative 'fringe
				                    `(:background ,fg-color))
	       (face-remap-add-relative 'header-line
				                    `(:overline ,fg-color 
						                        :box (:line-width (1 . 1)
								                                  :color ,bg-color)))
	       (face-remap-add-relative 'mode-line-active
				                    `(:overline "#89b4fa"
						                        :background ,(face-foreground 'vertical-border)
						                        :foreground ,(face-foreground 'vertical-border)
						                        :height 1.0))
	       (face-remap-add-relative 'mode-line-inactive
				                    `(:overline ,fg-color
						                        :background ,(face-foreground 'vertical-border)
						                        :foreground ,(face-foreground 'vertical-border)
						                        :height 1.0))
	       )))
  
  (set-window-margins nil 2 2)
  (when (eq (window-buffer) (current-buffer))
    (set-window-buffer nil (current-buffer))))

(defun nano-box-off ()
  "Remove box border from buffer"
  (interactive)
  (setq-local nano-box-state nil
	          left-fringe-width 1 
	          right-fringe-width 1
	          left-margin-width 0
	          right-margin-width 0
	          mode-line-format nano-box-mode-line-format)
  (mapc #'face-remap-remove-relative nano-box-cookies)
  (set-window-margins nil 0 0)
  (set-window-buffer nil (current-buffer)))

(defun nano-box ()
  "Toggle box border"
  (interactive)
  (if (not nano-box-state)
      (nano-box-on)
    (nano-box-off))
  (redisplay t))

;;(my/set-frame-padding)
;; Set border colors
;;(set-face-attribute 'vertical-border nil
;;		    :foreground "#161a2a"
;;		    :background "#161a2a")

;; Hook setup
;;(add-hook 'prog-mode-hook #'nano-box-on)
                                        ;(my/set-tab-theme)

;; FIXME TODO
(defun sly-eval-last-expression-eros ()
  (interactive)
  (destructuring-bind (output value)
                      (slime-eval `(swank:eval-and-grab-output ,(slime-last-expression)))
                      (eros--make-result-overlay (concat output value)
                        :where (point)
                        :duration eros-eval-result-duration)))

;; (sly-start-slynk-server)
;; (sly-eval `,(sly-pprint-eval-last-expression))


;; Tool-bar icons: transparent Maple NF nerd glyphs over the GTK tool-bar,
;; whose colour dots pins via #emacs-toolbar in gtk.css (read back below).
(require 'svg)

(defun my/open-init ()
  (interactive)
  (find-file user-init-file))

(defvar my/toolbar-actions
  '(("nf-cod-files"          dirvish          "Explorer")
    ("nf-cod-search"         consult-ripgrep  "Search")
    ("nf-cod-source_control" magit-status     "Source Control")
    ("nf-cod-terminal"       eat              "Terminal")
    ("nf-cod-extensions"     elpaca-manager   "Packages")
    ("nf-cod-settings_gear"  my/open-init     "Settings"))
  "Each entry: (CODICON COMMAND HELP). Add a line to add a button.")

(defun my/nerd-toolbar-image (codicon fg)
  "Transparent SVG of nerd CODICON in Maple Mono NF, glyph in FG."
  (let* ((glyph (nerd-icons-codicon codicon))
         (px 24)
         (svg (svg-create px px)))
    (svg-text svg glyph
              :font-family "Maple Mono NF"
              :font-size 18
              :fill fg :text-anchor "middle"
              :x (/ px 2) :y 19)
    (svg-image svg :ascent 'center :scale 1)))

(defun my/gtk-toolbar-bg ()
  (let ((f (expand-file-name "gtk-3.0/gtk.css" (getenv "XDG_CONFIG_HOME"))))
    (when (file-readable-p f)
      (with-temp-buffer
        (insert-file-contents f)
        (goto-char (point-min))
        (when (re-search-forward
               "#emacs-toolbar[^}]*background-color:[ \t]*\\(#[0-9a-fA-F]+\\)" nil t)
          (match-string 1))))))

(defun my/rebuild-toolbar (&rest _)
  "Build the tool-bar; match the `tool-bar' face to the GTK widget colour."
  (let ((bg (or (my/gtk-toolbar-bg) (face-attribute 'default :background nil t)))
        (fg (face-attribute 'default :foreground nil t))
        (map (make-sparse-keymap)))
    (dolist (a my/toolbar-actions)
      (pcase-let ((`(,icon ,cmd ,help) a))
        (tool-bar-local-item icon cmd (intern icon) map
                             :image (my/nerd-toolbar-image icon fg)
                             :help help)))
    (setq-default tool-bar-map map)
    (set-face-attribute 'tool-bar nil :background bg)))

(global-set-key [tool-bar]
                `(menu-item "tool bar" ignore
                            :filter (lambda (_) (default-value 'tool-bar-map))))

(setq tool-bar-position 'left
      tool-bar-style 'image)

;; Rebuild once a frame exists (daemon), and whenever the theme changes.
(add-hook 'server-after-make-frame-hook #'my/rebuild-toolbar 95)
(add-hook 'enable-theme-functions #'my/rebuild-toolbar)


(defun text-file-p (filename)
  "Return t if FILENAME is likely a text file."
  (and (not (string-match-p "~$" filename))  ; Skip backup files
       (not (string-match-p "\\.\\(png\\|jpe?g\\|gif\\|bmp\\|ico\\|tiff?\\|webp\\)$" filename))  ; Skip images
       (not (string-match-p "\\.\\(mp[34]\\|wav\\|ogg\\|flac\\|m4a\\|aac\\|wma\\)$" filename))   ; Skip audio
       (not (string-match-p "\\.\\(mp4\\|avi\\|mkv\\|mov\\|wmv\\|flv\\|webm\\)$" filename))      ; Skip video
       (not (string-match-p "\\.\\(pdf\\|doc\\|docx\\|xls\\|xlsx\\|ppt\\|pptx\\)$" filename))    ; Skip office docs
       (not (string-match-p "\\.\\(zip\\|rar\\|7z\\|tar\\|gz\\|bz2\\|xz\\)$" filename))          ; Skip archives
       (not (string-match-p "\\.\\(exe\\|dll\\|so\\|dylib\\|bin\\|dat\\)$" filename))            ; Skip binaries
       (not (string-match-p "\\.\\(sqlite\\|db\\)$" filename))))                                  ; Skip databases

(defun safe-read-file (filename)
  "Safely read contents of FILENAME, return nil if file appears to be binary."
  (when (file-readable-p filename)
    (with-temp-buffer
      (set-buffer-multibyte t)
      (insert-file-contents filename)
      ;; Check for null bytes which typically indicate binary content
      (unless (save-excursion
                (goto-char (point-min))
                (search-forward "\0" nil t))
        (buffer-string)))))

(defun list-project-files-with-contents ()
  "List all text files in the current project with their contents in an org buffer."
  (interactive)
  (if-let* ((project (project-current))
            (files (seq-filter #'text-file-p
                               (project-files project)))
            (buf (get-buffer-create "*Project Files*")))
      (with-current-buffer buf
        (org-mode)
        (erase-buffer)
        (dolist (file files)
          (insert (format "* %s\n" file))
          (when-let ((contents (safe-read-file file)))
            (insert contents)
            (unless (string-suffix-p "\n\n" contents)
              (insert "\n\n"))))
        (goto-char (point-min))
        (switch-to-buffer buf))
    (message "No project or readable text files found.")))
;; (defun my/set-frame-padding ()						      ;;
;;   "Set frame padding and window dividers"					      ;;
;;   (let ((bg-main (face-background 'default)))				      ;;
;;     ;; Set basic frame parameters						      ;;
;;     (modify-all-frames-parameters						      ;;
;;      `((internal-border-width . 15)						      ;;
;;        (right-divider-width . 30)						      ;;
;;        (left-fringe . 8)							      ;;
;;        (right-fringe . 8)))							      ;;
;;     										      ;;
;;     ;; Set window dividers							      ;;
;;     (custom-set-faces							      ;;
;;      ;; Make window dividers blend into background				      ;;
;;      `(vertical-border ((t :background ,bg-main :foreground ,bg-main)))	      ;;
;;      `(window-divider ((t :background ,bg-main :foreground ,bg-main)))	      ;;
;;      `(window-divider-first-pixel ((t :background ,bg-main :foreground ,bg-main))) ;;
;;      `(window-divider-last-pixel ((t :background ,bg-main :foreground ,bg-main)))  ;;
;;      ;; Make fringe match background						      ;;
;;      `(fringe ((t :background ,bg-main))))))					      ;;
;; (defun my/setup-ui ()
;;   (my/set-frame-padding)
;;   (global-tab-line-mode)
;;   (nano-box-on))
;;(my/setup-ui)
;;(add-hook 'after-init-hook #'my/setup-ui)
(defun list-project-files-with-contents ()
  (interactive)
  (let* ((files (seq-filter (lambda (f) (not (string-match-p "~$" f)))
			                (project-files (project-current))))
	     (buf (get-buffer-create "*Project Files*")))
    (with-current-buffer buf
      (org-mode)
      (erase-buffer)
      (dolist (file files)
	    (insert (format "* %s\n" file))
	    (when (file-readable-p file)
	      (let ((contents (with-temp-buffer
			                (insert-file-contents file)
			                (buffer-string))))
	        (insert contents)
	        (unless (string-suffix-p "\n\n" contents)
	          (insert "\n\n")))))
      (goto-char (point-min)))
    (switch-to-buffer buf)))

;; (set-face-attribute 'vertical-border nil			       ;;
;;                     :foreground "#161a2a"  ; Use your desired color ;;
;;                     :background "#161a2a")			       ;;
;; 								       ;;
;; (set-face-attribute 'line-number nil				       ;;
;;                     :background nil)				       ;;

;;; Custom interface
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("972174133853f03fd25edfa6fb614d7708459d87d15fdb90fbb6da928a532f0d"
     "0a2168af143fb09b67e4ea2a7cef857e8a7dad0ba3726b500c6a579775129635"
     "1bb8300c70034e287e222a529214eff80825474d79f98203517d13f5ff98cbe8"
     "f5723a6bcce8be0d90c759a0cf82bbfa7acfdd9739ef9c3c9248cf74b180d86f" default))
 '(org-export-backends '(ascii html icalendar latex md odt))
 '(package-selected-packages nil nil nil "Customized with use-package emacs")
 '(package-vc-selected-packages
   '((combobulate :vc-backend Git :url "https://github.com/mickeynp/combobulate")
     (gptel-aibo :vc-backend Git :url "https://github.com/dolmens/gptel-aibo")
     (nova :vc-backend Git :url "https://github.com/thisisran/nova")
     (ultra-scroll :vc-backend Git :url
                   "https://github.com/jdtsmith/ultra-scroll")
     (indent-bars :vc-backend Git :url "https://github.com/jdtsmith/indent-bars")))
 '(vertico-posframe-width 107))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(header-line-highlight ((t :box (:color "#d0d0d0"))))
 '(keycast-key ((t :box (:line-width 6 :color "#004a5f" :style nil))))
 '(line-number ((t (:inherit default))))
 '(minimap-font-face ((t (:family "BlockFont" :height 30))))
 )
;;; footer

;; Local Variables:
;; no-byte-compile: t
;; no-native-compile: t
;; no-update-autoloads: t
;; End:

