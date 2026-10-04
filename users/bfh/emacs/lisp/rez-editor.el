;; -*- lexical-binding: t -*-

(use-package emacs
  :ensure nil
  ;;  :bind* ("<C-return>" . other-window)
  :custom
  ;; C source code
  (auto-hscroll-mode 'current-line)
  ;; misc
  (auto-save-interval 64)
  (auto-save-timeout 2)
  (fill-column 78)
  (history-delete-duplicates t)
  (history-length 200)
  (message-log-max 16384)
  (redisplay-dont-pause t)
  (undo-limit 800000)
  (x-stretch-cursor t)

  (completion-ignored-extensions
   '(".a"
     ".aux"
     ".bbl"
     ".bin"
     ".blg"
     ".class"
     ".cp"
     ".cps"
     ".elc"
     ".fmt"
     ".fn"
     ".fns"
     ".git/"
     ".glo"
     ".glob"
     ".gmo"
     ".hg/"
     ".idx"
     ".ky"
     ".kys"
     ".la"
     ".lib"
     ".ln"
     ".lo"
     ".lof"
     ".lot"
     ".mem"
     ".mo"
     ".o"
     ".pg"
     ".pgs"
     ".pyc"
     ".pyo"
     ".so"
     ".tfm"
     ".toc"
     ".tp"
     ".tps"
     ".v.d"
     ".vio"
     ".vo" ".vok" ".vos"
     ".vr"
     ".vrs"
     "~"))

  ;; startup.el
  ;; advice.el
  (ad-redefinition-action 'accept)
  ;; files.el
  ;;  (backup-directory-alist '(("." . "~/.local/share/emacs/backups")))
  (delete-old-versions t)
  ;;  (directory-abbrev-alist
  ;;   '(("\\`/org" . "/home/bret.horne/doc/org")))
  (directory-free-space-args "-kh")
  (large-file-warning-threshold nil)
  (save-abbrevs 'silently)
  (trash-directory "~/.Trash")
  (version-control t)
  ;; simple.el
  (backward-delete-char-untabify-method 'untabify)
  ;; (column-number-mode t)
  ;; (indent-tabs-mode nil)
  ;; (kill-do-not-save-duplicates t)
  ;; (kill-ring-max 500)
  ;; (kill-whole-line t)
  ;; (mail-user-agent 'gnus-user-agent)
  ;; (next-line-add-newlines nil)
  ;; (save-interprogram-paste-before-kill t)
  ;; bytecomp.el
  (byte-compile-verbose nil)
  (custom-buffer-done-function 'kill-buffer)
  ;; (default-major-mode 'text-mode)
  ;; prog-mode.el
  (prettify-symbols-unprettify-at-point 'right-edge)
  ;; paragraphs.el
  (sentence-end-double-space nil)
  ;; paren.el
  (show-paren-delay 0)
  ;; window.el
  (same-window-buffer-names
   '("*eshell*"
     "*shell*"
     "*mail*"
     "*inferior-lisp*"
     "*ielm*"
     "*scheme*"))
  (switch-to-buffer-preserve-window-point t)
  ;; warnings.el
  (warning-minimum-log-level :error)
  ;; frame.el
  (frame-title-format nil)
  (window-divider-default-bottom-width 1)
  (window-divider-default-places 'bottom-only)
  ;; nsm.el
  ;;(nsm-settings-file (user-data "network-security.data"))
  :init
  (setq disabled-command-function nil) ;; enable all commands
  :config
  (add-hook 'after-save-hook
            #'executable-make-buffer-file-executable-if-script-p))

;;evil
(use-package undo-fu)

;;; Vim Bindings
(use-package evil
  :demand t
  :bind (("<escape>" . keyboard-escape-quit))
  :init
  ;; allows for using cgn
  ;; (setq evil-search-module 'evil-search)
  (setq evil-want-keybinding nil)
  :custom
  (evil-move-cursor-back nil)
  (evil-undo-system 'undo-fu)
  (evil-want-C-u-scroll t)
  :config
  (evil-mode 1))


;;; Vim Bindings Everywhere else
(use-package evil-collection
  :after evil
  :config
  (setq evil-want-integration t)
  (evil-collection-init))

;;meow
(use-package meow
  :disabled
  :config
  (defun meow-setup ()
    (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)
    (meow-motion-overwrite-define-key
     '("j" . meow-next)
     '("k" . meow-prev)
     '("<escape>" . ignore))
    (meow-leader-define-key
     ;; SPC j/k will run the original command in MOTION state.
     '("j" . "H-j")
     '("k" . "H-k")
     ;; Use SPC (0-9) for digit arguments.
     '("1" . meow-digit-argument)
     '("2" . meow-digit-argument)
     '("3" . meow-digit-argument)
     '("4" . meow-digit-argument)
     '("5" . meow-digit-argument)
     '("6" . meow-digit-argument)
     '("7" . meow-digit-argument)
     '("8" . meow-digit-argument)
     '("9" . meow-digit-argument)
     '("0" . meow-digit-argument)
     '("/" . meow-keypad-describe-key)
     '("?" . meow-cheatsheet))
    (meow-normal-define-key
     '("0" . meow-expand-0)
     '("9" . meow-expand-9)
     '("8" . meow-expand-8)
     '("7" . meow-expand-7)
     '("6" . meow-expand-6)
     '("5" . meow-expand-5)
     '("4" . meow-expand-4)
     '("3" . meow-expand-3)
     '("2" . meow-expand-2)
     '("1" . meow-expand-1)
     '("-" . negative-argument)
     '(";" . meow-reverse)
     '("," . meow-inner-of-thing)
     '("." . meow-bounds-of-thing)
     '("[" . meow-beginning-of-thing)
     '("]" . meow-end-of-thing)
     '("a" . meow-append)
     '("A" . meow-open-below)
     '("b" . meow-back-word)
     '("B" . meow-back-symbol)
     '("c" . meow-change)
     '("d" . meow-delete)
     '("D" . meow-backward-delete)
     '("e" . meow-next-word)
     '("E" . meow-next-symbol)
     '("f" . meow-find)
     '("g" . meow-cancel-selection)
     '("G" . meow-grab)
     '("h" . meow-left)
     '("H" . meow-left-expand)
     '("i" . meow-insert)
     '("I" . meow-open-above)
     '("j" . meow-next)
     '("J" . meow-next-expand)
     '("k" . meow-prev)
     '("K" . meow-prev-expand)
     '("l" . meow-right)
     '("L" . meow-right-expand)
     '("m" . meow-join)
     '("n" . meow-search)
     '("o" . meow-block)
     '("O" . meow-to-block)
     '("p" . meow-yank)
     '("q" . meow-quit)
     '("Q" . meow-goto-line)
     '("r" . meow-replace)
     '("R" . meow-swap-grab)
     '("s" . meow-kill)
     '("t" . meow-till)
     '("u" . meow-undo)
     '("U" . meow-undo-in-selection)
     '("v" . meow-visit)
     '("w" . meow-mark-word)
     '("W" . meow-mark-symbol)
     '("x" . meow-line)
     '("X" . meow-goto-line)
     '("y" . meow-save)
     '("Y" . meow-sync-grab)
     '("z" . meow-pop-selection)
     '("'" . repeat)
     '("<escape>" . ignore)))
  
  (meow-setup)
  (meow-global-mode 1))

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



(keymap-global-set "M-o" 'other-window)
(keymap-global-set "C-w" 'backward-kill-word)
(keymap-global-set "C-x C-k" 'kill-region)
(keymap-global-set "C-x C-m" 'execute-extended-command)
(keymap-global-set "C-z" 'zap-up-to-char)

(provide 'rez-editor)
