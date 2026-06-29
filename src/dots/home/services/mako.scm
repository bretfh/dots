;;; mako (notification daemon) config generated from a <theme>. mako uses an INI
;;; file: a headerless global block plus [criteria] sections. The surface is
;;; transparent, so the niri "notifications" layer-rule blur is the chrome.
;;; Returns home-xdg-configuration-files entries.

(define-module (dots home services mako)
  #:use-module (guix gexp)
  #:use-module (dots theme base)
  #:use-module (dots config ini)
  #:export (mako-config
            mako-capability))

(define (mako-config theme)
  "Return the mako config contents themed from THEME."
  (define font (theme-fonts theme))
  (ini
   `((#f (font . ,(string-append (fonts-mono font) " 11"))
         (background-color . "#00000000")
         (text-color . ,(theme-color theme 'fg))
         (border-size . 0)
         (border-radius . 0)
         (padding . 8)
         (default-timeout . 6000)
         (anchor . top-right))
     ("urgency=high" (default-timeout . 0)))))

(define (mako-capability theme)
  "Return home-xdg-configuration-files entries for mako themed from THEME."
  `(("mako/config"
     ,(plain-file "mako-config" (mako-config theme)))))
