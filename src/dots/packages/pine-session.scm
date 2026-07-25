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

;;; river's init. It keeps the window manager up, because river holds the
;;; windows whatever happens to it and a fresh manager re-binds and
;;; re-arranges from the daemon's tree.
;;;
;;; It stops when the compositor does. wm-exit ends the session through the
;;; protocol, so river exits and unlinks its socket; without that test the
;;; loop would keep launching a manager at a compositor that is gone, long
;;; after the session handed back to the display manager. A manager that
;;; dies within seconds is failing rather than crashing once, so a run of
;;; those gives up instead of spinning.
(define %init-script "\
#!/bin/sh
export XDG_CURRENT_DESKTOP=pine
log=\"${XDG_STATE_HOME:-$HOME/.local/state}/pine-wm.log\"
socket=\"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}\"
failures=0

while [ -S \"$socket\" ] && [ \"$failures\" -lt 10 ]; do
  started=$(date +%s)
  LD_LIBRARY_PATH=$GUIX_ENVIRONMENT/lib \\
  CL_SOURCE_REGISTRY=$HOME/git/cl/pine//:$GUIX_ENVIRONMENT/share/common-lisp// \\
  ASDF_OUTPUT_TRANSLATIONS=/:$HOME/.cache/common-lisp/pine/ \\
  sbcl --no-userinit --non-interactive \\
       --eval '(require :asdf)' \\
       --eval '(asdf:load-system :pine/wayland)' \\
       --eval '(pine.wl-wm:run-wm)' >>\"$log\" 2>&1
  if [ $(( $(date +%s) - started )) -lt 5 ]; then
    failures=$(( failures + 1 ))
  else
    failures=0
  fi
  sleep 1
done
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
cd ~a || exit 1~%~
exec guix shell -m manifest.scm -- river -c ~a~%"
                        #$%repo init)))
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
