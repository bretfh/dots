;;; swaybg, driven by the rice script: it picks a random background and
;;; replaces the running instance, so the same command is both the session
;;; startup and the Mod+W action.

(define-module (dots home services swaybg)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (dots home component)
  #:use-module (dots assets)
  #:export (<swaybg> swaybg))

(define-class <swaybg> (<wallpaper>))
(define swaybg (make <swaybg> #:name 'swaybg))

(define-method (component-launch (c <swaybg>)) "bash ~/.config/rice/wallpaper")

(define-method (component-config-files (c <swaybg>) desktop)
  `(("rice/wallpaper"
     ,(local-file (string-append assets-dir "/rice/wallpaper")))
    ("rice/backgrounds"
     ,(local-file (string-append assets-dir "/rice/imgs/background")
                  #:recursive? #t))))
