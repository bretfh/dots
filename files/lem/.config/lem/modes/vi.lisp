(in-package :arc)

;; SPC b
(defvar *space-b-keymap*
  (make-keymap :name '*space-b-keymap*)
  "buffer menu")
(define-keys *space-b-keymap*
             ("b" 'lem-core/commands/window:select-buffer)
             ("d" 'lem-core/commands/window:kill-buffer)
             ("n" 'lem-core/commands/window:next-buffer)
             ("p" 'lem-core/commands/window:previous-buffer)
             ("r" 'lem-core/commands/file:revert-buffer))
;; SPC f
(defvar *space-f-keymap*
  (make-keymap :name '*space-f-keymap*)
  "file menu")
(define-keys *space-f-keymap*
             ("f" 'lem-core/commands/file:find-file)
             ("F" 'lem-core/commands/file:find-file-recursively)
             ("t" 'lem/filer::filer))
;; SPC g
(defvar *space-g-keymap*
  (make-keymap :name '*space-g-keymap*)
  "git menu")
(define-keys *space-g-keymap*
             ("s" 'lem/legit::legit-status))
;; SPC h
(defvar *space-h-keymap*
  (make-keymap :name '*space-h-keymap*)
  "help menu")
(define-keys *space-h-keymap*
             ("a" 'lem-lisp-mode/internal:lisp-apropos-all)
             ("b" 'lem-core/commands/help::describe-bindings)
             ("f" 'lem-lisp-mode/internal:lisp-describe-symbol)
             ("k" 'lem-core/commands/help::describe-key)
             ("m" 'lem-core/commands/help::describe-mode))
;; SPC j
(defvar *space-j-keymap*
  (make-keymap :name '*space-j-keymap*)
  "jump menu")
(define-keys *space-j-keymap*
             ("i" 'lem/detective:detective-all))
;; SPC p
(defvar *space-p-keymap*
  (make-keymap :name '*space-p-keymap*)
  "project menu")
(define-keys *space-p-keymap*
             ("f" 'lem-core/commands/project:project-find-file)
             ("p" 'lem-core/commands/project:project-switch)
             ("g" 'lem/grep::project-grep)
             ("s" 'lem-core/commands/project:project-save)
             ("t" 'lem/filer::filer)
             ("u" 'lem-core/commands/project:project-unsave))
;; SPC t
(defvar *space-t-keymap*
  (make-keymap :name '*space-t-keymap*)
  "toggle menu")
(define-keys *space-t-keymap*
             ("f" 'lem-core/commands/frame:toggle-frame-fullscreen)
             ("n" 'lem/line-numbers:toggle-line-numbers)
             ("p" 'lem/show-paren::toggle-show-paren)
             ("s" 'lem-core::list-color-themes)
             ("w" 'lem-core/commands/window::toggle-line-wrap))
;; SPC w
(defvar *space-w-keymap*
  (make-keymap :name '*space-w-keymap*)
  "window menu")
(define-keys *space-w-keymap*
             ("0" 'lem-core/commands/window:delete-active-window)
             ("1" 'lem-core/commands/window:delete-other-windows)
             ("h" 'lem-core/commands/window:window-move-left)
             ("j" 'lem-core/commands/window:window-move-down)
             ("k" 'lem-core/commands/window:window-move-up)
             ("l" 'lem-core/commands/window:window-move-right)
             ("n" 'lem-core/commands/window:next-window)
             ("p" 'lem-core/commands/window:previous-window)
             ("-" 'lem-core/commands/window:split-active-window-vertically)
             ("/" 'lem-core/commands/window:split-active-window-horizontally))
;; SPC
(defvar *space-keymap*
  (make-keymap :name '*space-keymap*)
  "The root keymap for the space menu.")
(define-keys *space-keymap*
             ("b" *space-b-keymap*)
             ("f" *space-f-keymap*)
             ("g" *space-g-keymap*)
             ("h" *space-h-keymap*)
             ("j" *space-j-keymap*)
             ("p" *space-p-keymap*)
             ("t" *space-t-keymap*)
             ("w" *space-w-keymap*)
             ("'" 'lem-terminal/terminal-mode::terminal)
             ("Space" 'lem-core/commands/other:execute-command))
(define-key lem-vi-mode:*normal-keymap* "Space" *space-keymap*) ; leader
(define-key lem-vi-mode:*insert-keymap* "M-m" *space-keymap*)   ; alternative leader
(define-keys *global-keymap*
             ("Shift-Insert" 'lem-vi-mode/commands:vi-paste-after)
             ("C-V" 'lem-vi-mode/commands:vi-paste-after))
(define-keys *global-keymap*
             ("C-h a" 'lem-lisp-mode/internal:lisp-apropos-all)
             ("C-h b" 'lem-core/commands/help::describe-bindings)
             ("C-h f" 'lem-lisp-mode/internal:lisp-describe-symbol)
             ("C-h k" 'lem-core/commands/help::describe-key)
             ("C-h m" 'lem-core/commands/help::describe-mode))
(lem-vi-mode:vi-mode)

;;fc-list --format="%{family[0]}\n" | sort | uniq | fzf
(lem/line-numbers:toggle-line-numbers)
(setf lem:*auto-format* t)
(setf (variable-value 'line-wrap :global) t)

;; (when (typep (lem:implementation) 'lem-sdl2/sdl2:sdl2)
;;   (let ((font-regular #P"/home/jfaz/.local/share/fonts/Greybeard-13px.ttf")
;;         (font-bold #P"/home/jfaz/.local/share/fonts/Greybeard-13px-Bold.ttf"))
;;     (lem-sdl2/display:change-font (lem-sdl2/display:current-display)
;;                                   (lem-sdl2/font:make-font-config
;;                                    :latin-normal-file font-regular
;;                                    :latin-bold-file font-bold))))

;;(define-key lem-vi-mode:*normal-keymap* "Space l w" 'lem-core/commands/window::toggle-line-wrap)
(define-key lem-vi-mode:*normal-keymap* "C-i" 'lem-vi-mode/binds::vi-jump-next)
(define-key lem-vi-mode:*normal-keymap* "C-o" 'lem-vi-mode/binds::vi-jump-back)

;; For Pulumi YAML files
;;(lem-lsp-mode/lsp-mode::define-language-spec
;;    (pulumi-yaml-spec lem-yaml-mode:yaml-mode)
;;  :language-id "pulumi-yaml"
;;  :root-uri-patterns '("Pulumi.yaml")
;;  :command '("pulumi-lsp" "--stdio")
;;  :install-command "go install github.com/pulumi/pulumi-lsp/cmd/pulumi-lsp@latest"
;;  :readme-url "https://github.com/pulumi/pulumi-lsp"
;;  :connection-mode :stdio)
;;
;;;; For Python files in the project
;;(lem-lsp-mode:define-language-spec (python-spec lem-python-mode:python-mode)
;;  :language-id "python"
;;  :root-uri-patterns '("setup.py" "pyproject.toml" "requirements.txt" "__init__.py")
;;  :command '("pylsp" "--stdio")
;;  :install-command "pip install python-lsp-server"
;;  :readme-url "https://github.com/python-lsp/python-lsp-server"
;;  :connection-mode :stdio)
