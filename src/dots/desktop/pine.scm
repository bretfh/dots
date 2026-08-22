;;; pine: the desktop daemon that feeds the pine bar/echo/panels. It is the
;;; parallel to the eww broker -- a home shepherd service that owns the daemon's
;;; lifecycle (single instance, respawn, stop). One image holds the tree, the
;;; systems its config declares, the store and its own screen; there is no
;;; second process behind the surfaces.

(define-module (dots desktop pine)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu services shepherd)
  #:use-module ((pine packages pine) #:select ((pine . pine-package)))
  #:use-module (dots core)
  #:use-module (dots assets)
  #:export (home-pine-service-type
            <pine> pine))

(define (home-pine-shepherd-service config)
  (list
   (shepherd-service
    (provision '(pine-daemon))
    (documentation "Pine desktop daemon: sources + surfaces feeding the pine bar.")
    (start #~(make-forkexec-constructor
              ;; the home shepherd outlives the session and has no display in
              ;; its environment; pine reads WAYLAND_DISPLAY once, at start.
              (list "/bin/sh" "-c"
                    (string-append
                     "for s in \"$XDG_RUNTIME_DIR\"/wayland-[0-9]*; do "
                     "case \"$s\" in *.lock) ;; "
                     "*) export WAYLAND_DISPLAY=${s##*/}; break ;; esac; done; "
                     "for s in \"$XDG_RUNTIME_DIR\"/niri.*.sock; do "
                     "[ -S \"$s\" ] && { export NIRI_SOCKET=\"$s\"; break; }; done; "
                     "exec " #$pine-package:bin "/bin/pine daemon"))
              #:log-file (string-append
                          (or (getenv "XDG_STATE_HOME")
                              (string-append (getenv "HOME") "/.local/state"))
                          "/pine-daemon.log")))
    (stop #~(make-kill-destructor))
    (respawn? #t))))

(define (home-pine-profile-service config)
  (list (list pine-package "bin")))

(define home-pine-service-type
  (service-type
   (name 'home-pine)
   (extensions
    (list (service-extension home-shepherd-service-type
                             home-pine-shepherd-service)
          (service-extension home-profile-service-type
                             home-pine-profile-service)))
   (default-value #f)
   (description "Pine desktop daemon shepherd service.")))


;;; the component

(define-class <pine> (<bar>))
(define pine (make <pine> #:name 'pine))

;; pine is not a spec string; it reaches the profile through the service, the
;; way emacs does.
(define-method (component-packages (c <pine>)) '())

;; What this machine runs, in pine's own language: the systems, the devices, the
;; surfaces and the chords. pine reads it from XDG_CONFIG_HOME itself, so this
;; only has to put it there.
(define-method (component-config-files (c <pine>) desktop)
  `(("pine/init.lisp"
     ,(local-file (string-append assets-dir "/pine/init.lisp")))))

;; The daemon owns the frontends and fills WAYLAND_DISPLAY/NIRI_SOCKET itself,
;; but the home shepherd outlives the session, so starting pine in a session
;; means pointing the running daemon at this session's display -- the same
;; move emacs makes.
(define-method (component-launch (c <pine>)) "herd restart pine-daemon")

;; The daemon is only declared when pine is the primary bar.
(define-method (component-services (c <pine>) desktop)
  (list (service home-pine-service-type)))
