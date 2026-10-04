(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("476bd6779c0072b0a44ad37990444a6a7bdff2f1a9dd99b9430286e359d98f3c" "cdb768021bf99e838364dd5e7fc22d9b6f790124c97be379a5bda4f900e50c26" "508815b919044c42b7942c49b957133a136210ee0dced645512f8d4ddc5f6b4b" "308ead333d5dfc7d64258a9d3d46f9e479e4b62bdf33a8ea8700423842cae32e" "6a948097182a7f975fbff55da5979989a8dc1f1ed47a6344c5c9579c0a55316e" "74e2ed63173b47d6dc9a82a9a8a6a9048d89760df18bc7033c5f91ff4d083e37" "06ed754b259cb54c30c658502f843937ff19f8b53597ac28577ec33bb084fa52" default))
 '(kaolin-theme-linum-hl-line-style t)
 '(kaolin-themes-distinct-fringe t)
 '(lambda-line-position 'top)
 '(lambda-line-time-day-and-date-format "")
 '(lambda-line-tty-mod-symbol "\"\\ue0b0\"")
 '(org-agenda-files nil)
 '(package-selected-packages
   '(repl-driven-development cider-eval-sexp-fu which-key-posframe snow geiser-guile hide-mode-line clojure-ts-mode janet-mode a-janet-spork-client janet-ts-mode ajrepl monroe sly-asdf sly-repl-ansi-color sly-quicklisp sly-overlay sly mini-frame tree-sitter-langs eldoc-box vertico-posframe treesit-auto blamer diff-hl nyan-mode zone-nyan pulsar go-playground web-mode doom-modeline pdf-tools lsp-dart catppuccin-theme org-modern meow all-the-icons-nerd-fonts tab-bar-echo-area bufler centaur-tabs frame-tabs ox-gfm ox-pandoc cider fennel-mode lua-mode vterm yasnippet terraform-mode go-mode eat mistty git-gutter+ evil-terminal-cursor-changer lambda-line lsp-ui lsp-treemacs treemacs lsp-mode flycheck rustic spacemacs-theme ef-themes prism doom-themes mini-echo eglot sr-speedbar pretty-speedbar sixcolors-mode xterm-color shr-tag-pre-highlight base16-theme termbright-theme solaire-mode yaml-mode yaml pcmpl-args yascroll embark-consult which-key embark wgrep dired-git-info dirvish eglot-tempel tempel-collection tempel templ paredit magit fireplace parinfer-rust-mode ligature ligatures markdown-mode dired-subtree vertico orderless marginalia kind-icon git-gutter-fringe corfu consult cape all-the-icons-completion kaolin-themes tabspaces undo-fu evil evil-collection shelldon bash-completion))
 '(package-vc-selected-packages
   '((a-janet-spork-client :vc-backend Git :url "https://github.com/sogaiu/a-janet-spork-client")
     (janet-ts-mode :vc-backend Git :url "https://github.com/sogaiu/janet-ts-mode")
     (ajrepl :vc-backend Git :url "https://github.com/sogaiu/ajrepl")
     (lambda-line :vc-backend Git :url "https://github.com/Lambda-Emacs/lambda-line")))
 '(safe-local-variable-values
   '((eval progn
	   (make-variable-buffer-local 'cider-jack-in-nrepl-middlewares)
	   (add-to-list 'cider-jack-in-nrepl-middlewares "shadow.cljs.devtools.server.nrepl/middleware"))
     (cider-default-cljs-repl . custom)
     (cider-preferred-build-tool . clojure-cli)
     (cider-clojure-cli-global-options . "-A:dev")
     (cider-shadow-default-options . "frontend")
     (cider-default-cljs-repl . shadow)
     (cider-preferred-build-tool . shadow-cljs)))
 '(window-divider-default-bottom-width 1 nil nil "Customized with use-package emacs")
 '(window-divider-default-places t nil nil "Customized with use-package emacs"))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
