;;; sway -- the fallback compositor. Its config is a curated file: it carries
;;; its own palette, its own binds and its own startups, none of it generated
;;; from the desktop declaration. Promoting sway would give a session that
;;; ignores <desktop>.

(define-module (dots home services sway)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (dots core)
  #:use-module (dots desktop)
  #:export (<sway> sway))

(define-class <sway> (<compositor>))
(define sway (make <sway> #:name 'sway))

(define-method (component-quit (c <sway>)) "swaymsg exit")

(define-method (component-config-files (c <sway>) desktop)
  `(("sway/config"
     ,(desktop-asset desktop "sway/.config/sway"))))
