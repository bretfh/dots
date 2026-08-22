;;; vim -- the fallback editor. The whole ~/.config/vim tree, plugins included,
;;; is curated; nothing is generated from the theme.

(define-module (dots home services vim)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (dots core)
  #:use-module (dots assets)
  #:export (<vim> vim))

(define-class <vim> (<editor>))
(define vim (make <vim> #:name 'vim))

(define-method (component-config-files (c <vim>) desktop)
  `(("vim" ,(local-file (string-append assets-dir "/vim/.config/vim")
                        #:recursive? #t))))
