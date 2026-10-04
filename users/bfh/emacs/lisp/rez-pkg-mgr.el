(require 'package)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
			 ("melpa" . "https://melpa.org/packages/")
			 ("nongnu" . "https://elpa.nongnu.org/nongnu/")))

(setq package-archive-priorities
      '(("gnu" . 3)
	("melpa". 2)
	("nongnu" . 1)))

(setq package-selected-packages
      '(embark-consult which-key embark wgrep dired-git-info
		       dirvish eglot-tempel tempel-collection
		       tempel templ paredit magit fireplace
		       parinfer-rust-mode ligature ligatures
		       markdown-mode dired-subtree vertico orderless
		       marginalia kind-icon git-gutter-fringe corfu
		       consult cape all-the-icons-completion
		       kaolin-themes tabspaces undo-fu evil evil-collection
		       shelldon bash-completion))

(package-install-selected-packages)
(package-initialize)

(setq package-quickstart t)
;;(setq use-package-compute-statistics t)

(provide 'rez-pkg-mgr)

