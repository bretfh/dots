;;; sill: the window manager, and the bar and panels it draws on the same
;;; connection. Unlike the eww broker there is no daemon here and nothing to
;;; keep alive: the session start is the program, and under someone else's
;;; compositor the same binary comes up as layer-shell surfaces only.

(define-module (dots home services sill)
  #:use-module (oop goops)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module ((sill packages sill) #:select ((sill . sill-package)))
  #:use-module (dots core)
  #:use-module (dots desktop)
  #:export (home-sill-service-type <sill> sill))

;;; No daemon: the profile entry is the whole of it. sill comes from its own
;;; channel, so it reaches the profile as a package and not as a spec string.

(define home-sill-service-type
  (service-type
   (name 'home-sill)
   (extensions
    (list (service-extension home-profile-service-type
                             (lambda (config) (list (list sill-package "bin"))))))
   (default-value #f)
   (description "sill, in the home profile.")))

(define-class <sill> (<bar>))
(define sill (make <sill> #:name 'sill))

;; it reaches the profile through the service, the way pine and emacs did.
(define-method (component-packages (c <sill>)) '())

(define-method (component-services (c <sill>) desktop)
  (list (service home-sill-service-type)))

;; What this machine draws and what its chords do, in sill's own language.
;; sill reads it from XDG_CONFIG_HOME itself, so this only has to put it there.
(define-method (component-config-files (c <sill>) desktop)
  `(("sill/init.lisp"
     ,(desktop-asset desktop "sill/init.lisp"))))

;; Under river, the session start is already sill and this does nothing twice
;; -- a second sill finds no window manager global to bind and would put a
;; second bar up. Under another compositor it is the bar, and starts like one.
(define-method (component-autostart (c <sill>) desktop)
  (if (eq? 'sill (component-name (desktop-compositor desktop)))
      #f
      (component-launch c)))

;; The surfaces it puts on screen, so the compositor can round and blur them
;; without knowing whose they are.
(define-method (component-layers (c <sill>))
  '(("sill" (layer . "top") (radius . 12) (blur? . #t))))
