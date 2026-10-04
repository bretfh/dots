(use-package rustic
  :init
  (setq rustic-cargo-bin "cargo"))
;;  (push 'rustic-clippy flycheck-checkers))

(use-package go-mode)
(use-package lua-mode)
(use-package fennel-mode
  ;;mm maybe https://github.com/andreyorst/fennel-proto-repl-protocol
  :ensure t
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

(use-package terraform-mode)
(use-package cider-mode)

(use-package js
  :mode "\\.js'"
  :config
;;  (setq js-indent-level --indent-width)
  :hook
  (((js-mode
     typescript-mode) . subword-mode)))

(use-package typescript-mode
  :mode "\\.ts?\\'"
  :hook ((typescript-mode . subword-mode))
  :config
  (setq-default typescript-indent-level --indent-width))

(use-package css-mode
  :mode "\\.s?css\\'")

(use-package web-mode
  :mode (("\\.html?\\'" . web-mode))
  :config
;;  (setq web-mode-markup-indent-offset --indent-width)
;;  (setq web-mode-code-indent-offset --indent-width)
;;  (setq web-mode-css-indent-offset --indent-width)
  (setq web-mode-content-types-alist '(("jsx" . "\\.js[x]?\\'"))))

(use-package sly
  :hook ((lisp-mode . sly-mode))
  :config
  (setq inferior-lisp-program "ros -Q run")
  (setq org-babel-lisp-eval-fn #'sly-eval)
  (setq inferior-lisp-program "sbcl"))    

(use-package sly-asdf
  :config
  (add-to-list 'sly-contribs 'sly-asdf 'append))

(use-package nix-mode
  :mode "\\.nix\\'")

(use-package ansible
  :defer t
  :hook (yaml-mode-hook . ansible))

(use-package eglot
  :init
  (setq read-process-output-max (* 1024 1024));;1mb
  :hook ((ansible-minor-mode . eglot)))

(provide 'rez-lsp)
