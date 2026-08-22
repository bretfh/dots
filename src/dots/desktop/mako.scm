;;; mako (notification daemon) config generated from a <theme>. mako uses an INI
;;; file: a headerless global block plus [criteria] sections. The surface is
;;; transparent, so the niri "notifications" layer-rule blur is the chrome.
;;; Returns home-xdg-configuration-files entries.

(define-module (dots desktop mako)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (dots theme base)
  #:use-module (dots config ini)
  #:use-module (dots core)
  #:export (mako-config
            <mako> mako))

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

(define-class <mako> (<notifier>))
(define mako (make <mako> #:name 'mako))

(define-method (component-reload (c <mako>)) "makoctl reload")

;; The surface is fully transparent; the compositor's blur on this namespace
;; is the whole chrome.
(define-method (component-layers (c <mako>))
  '(("notifications" (radius . 0) (blur? . #t))))

(define-method (component-config-files (c <mako>) desktop)
  `(("mako/config"
     ,(plain-file "mako-config" (mako-config (desktop-theme desktop))))))
