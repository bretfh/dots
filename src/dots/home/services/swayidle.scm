;;; swayidle -- locks the session on idle and before sleep. It does not know
;;; what a lock screen is; it asks the desktop what fills the lock role.

(define-module (dots home services swayidle)
  #:use-module (oop goops)
  #:use-module (ice-9 format)
  #:use-module (dots core)
  #:use-module (dots desktop)
  #:export (<swayidle> swayidle))

(define-class <swayidle> (<idle>))
(define swayidle (make <swayidle> #:name 'swayidle))

(define-method (component-launch (c <swayidle>)) "swayidle -w")

(define-method (component-autostart (c <swayidle>) desktop)
  (let ((lock (and=> (desktop-lock desktop) component-command)))
    (and lock
         (format #f "~a timeout 600 '~a -d' before-sleep '~a -d'"
                 (component-launch c) lock lock))))
