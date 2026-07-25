;;; The pine session: a wayland-sessions entry so the display manager offers
;;; river with pine as its window manager, beside niri.
;;;
;;; river and pine both come from pine's own manifest, entered once at session
;;; start, so the session runs the working tree: iterate on pine and log back
;;; in, no reconfigure. Only this entry is declared here.
;;;
;;; The sbcl invocation matches the repo's Makefile exactly, and must: without
;;; --no-userinit and an explicit CL_SOURCE_REGISTRY, ~/.sbclrc pulls in ocicl
;;; and ASDF resolves pine's dependencies out of whatever checkout it finds
;;; first, which is how the session came up with an ocicl cl-sqlite that has
;;; no library to load.
;;;
;;; The daemon is the home-pine shepherd service, already running by the time
;;; a session starts; the window manager attaches to it over remoting and
;;; retries until it answers, so start order does not matter.

(define-module (dots packages pine-session)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (pine-session))

(define %repo "$HOME/git/cl/pine")

;;; The keyboard, matching the niri session: caps lock is another control.
;;; wlroots reads these, so river needs no configuration of its own for it.
(define %xkb-layout "us")
(define %xkb-options "ctrl:swapcaps")

;;; river's init. The daemon is started at login by its own service, before
;;; any compositor exists, so it has no display and starts nothing. This tells
;;; it which display the session is on, and the daemon takes it from there.
(define %init-script "\
#!/bin/sh
# river runs this once it is up. Its whole job is to tell the daemon which
# display this session is on. The daemon then starts and supervises the
# frontends the configuration asks for, the window manager included.
export XDG_CURRENT_DESKTOP=pine
log=\"${XDG_STATE_HOME:-$HOME/.local/state}/pine-session.log\"

cd $HOME/git/cl/pine || exit 1
LD_LIBRARY_PATH=$GUIX_ENVIRONMENT/lib \\
CL_SOURCE_REGISTRY=$HOME/git/cl/pine//:$GUIX_ENVIRONMENT/share/common-lisp// \\
ASDF_OUTPUT_TRANSLATIONS=/:$HOME/.cache/common-lisp/pine/ \\
exec sbcl --no-userinit --non-interactive \\
     --eval '(require :asdf)' \\
     --eval '(asdf:load-system :pine)' \\
     --eval '(pine::cli (list \"session\"))' >>\"$log\" 2>&1
")


(define-public pine-session
  (package
    (name "pine-session")
    (version "0.0.1")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((bin (string-append #$output "/bin"))
                 (sessions (string-append #$output "/share/wayland-sessions"))
                 (init (string-append bin "/pine-session-init"))
                 (start (string-append bin "/pine-session")))
            (mkdir-p bin)
            (mkdir-p sessions)

            (call-with-output-file init
              (lambda (port) (display #$%init-script port)))
            (chmod init #o555)

            ;; What the display manager starts: the manifest's environment
            ;; around river, with the window manager as river's init.
            (call-with-output-file start
              (lambda (port)
                (format port "#!/bin/sh~%~
export XKB_DEFAULT_LAYOUT=~a~%~
export XKB_DEFAULT_OPTIONS=~a~%~
cd ~a || exit 1~%~
exec guix shell -m manifest.scm -- river -c ~a~%"
                        #$%xkb-layout #$%xkb-options #$%repo init)))
            (chmod start #o555)

            (call-with-output-file (string-append sessions "/pine.desktop")
              (lambda (port)
                (format port "[Desktop Entry]~%~
Name=pine~%~
Comment=river with pine as the window manager~%~
Exec=~a~%~
Type=Application~%"
                        start)))))))
    (home-page "https://codeberg.org/river/river")
    (synopsis "Wayland session entry for pine on river")
    (description "A wayland-sessions entry that starts river with pine as its
window manager, running from pine's working tree through its own manifest.")
    (license license:expat)))
