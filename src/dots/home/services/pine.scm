;;; pine: the desktop daemon that feeds the pine bar/echo/panels. It is the
;;; parallel to the eww broker -- a home shepherd service that owns the daemon's
;;; lifecycle (single instance, respawn, stop). The daemon is run the same way
;;; `make daemon' runs it: a guix shell over the repo's manifest, then sbcl
;;; loading :pine and calling (pine:run-daemon). The GUI (the desktop app) is a
;;; niri spawn-at-startup (see desktop-launch-bar), in-session, so it has the
;;; wayland display; the daemon fills WAYLAND_DISPLAY/NIRI_SOCKET itself.

(define-module (dots home services pine)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu services shepherd)
  #:export (home-pine-service-type))

(define (home-pine-shepherd-service config)
  (list
   (shepherd-service
    (provision '(pine-daemon))
    (documentation "Pine desktop daemon: sources + surfaces feeding the pine bar.")
    (start #~(make-forkexec-constructor
              (list "/bin/sh" "-c"
                    (string-append
                     "cd $HOME/git/cl/pine && "
                     "exec guix shell -m manifest.scm -- sh -c "
                     "'LD_LIBRARY_PATH=\"$GUIX_ENVIRONMENT/lib\" "
                     ;; hermetic like the Makefile: without --no-userinit and
                     ;; an explicit registry, ~/.sbclrc loads ocicl and ASDF
                     ;; resolves pine's dependencies out of whatever checkout
                     ;; it finds first -- an ocicl cl-sqlite with no library
                     ;; to load takes the daemon down on every start.
                     "CL_SOURCE_REGISTRY=\"$HOME/git/cl/pine//:$GUIX_ENVIRONMENT/share/common-lisp//\" "
                     "ASDF_OUTPUT_TRANSLATIONS=\"/:$HOME/.cache/common-lisp/pine/\" "
                     "exec sbcl --no-userinit --non-interactive "
                     "--eval \"(require :asdf)\" "
                     "--eval \"(asdf:load-system :pine)\" "
                     "--eval \"(pine:run-daemon)\"'"))
              #:log-file (string-append
                          (or (getenv "XDG_STATE_HOME")
                              (string-append (getenv "HOME") "/.local/state"))
                          "/pine-daemon.log")))
    (stop #~(make-kill-destructor))
    (respawn? #t))))

(define home-pine-service-type
  (service-type
   (name 'home-pine)
   (extensions
    (list (service-extension home-shepherd-service-type
                             home-pine-shepherd-service)))
   (default-value #f)
   (description "Pine desktop daemon shepherd service.")))
