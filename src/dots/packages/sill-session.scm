;;; The sill session: a wayland-sessions entry so the display manager offers
;;; river with sill as its window manager, beside niri.
;;;
;;; river hands the windows to a manager and lays out nothing itself; sill is
;;; that manager, and puts its own bar and panels on the same connection. One
;;; process: there is no daemon behind the surfaces and nothing to start first.
;;;
;;; What a display manager puts in the environment is not ours to assume, and
;;; everything sill reads the machine with is a program it shells out to --
;;; wpctl, playerctl, nmcli, brightnessctl, wl-paste, the terminal a chord
;;; opens. So the session puts this user's profiles on PATH itself; without it
;;; every driver is simply absent and the bar comes up with nothing in it.

(define-module (dots packages sill-session)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (sill packages river)
  #:use-module ((sill packages sill) #:select ((sill . sill-package)))
  #:use-module (dots input)
  #:export (sill-session))

;;; river runs this once it is up, and it is the whole session: sill binds
;;; river's window management on the display it is handed, reads
;;; ~/.config/sill/init.lisp, and stays until the session ends.
(define %init-script "\
#!/bin/sh
export XDG_CURRENT_DESKTOP=sill
export PATH=\"$HOME/.guix-home/profile/bin:$HOME/.guix-profile/bin:$PATH\"
export XDG_DATA_DIRS=\"$HOME/.guix-home/profile/share:$HOME/.guix-profile/share:${XDG_DATA_DIRS:-/run/current-system/profile/share}\"
log=\"${XDG_STATE_HOME:-$HOME/.local/state}/sill.log\"
mkdir -p \"$(dirname \"$log\")\"

exec ~a >>\"$log\" 2>&1
")

;;; The keyboard is the caller's declaration, the one the niri session also
;;; reads. wlroots picks it up, so river needs no configuration of its own.
(define (sill-session keyboard)
  (define %xkb-layout  (keyboard-layout keyboard))
  (define %xkb-options (keyboard-options-string keyboard))
  (package
    (name "sill-session")
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
                 (init (string-append bin "/sill-session-init"))
                 (start (string-append bin "/sill-session")))
            (mkdir-p bin)
            (mkdir-p sessions)

            (call-with-output-file init
              (lambda (port)
                (format port #$%init-script
                        (string-append #$sill-package:bin "/bin/sill"))))
            (chmod init #o555)

            ;; What the display manager starts: river from the store, with
            ;; sill as its manager.
            (call-with-output-file start
              (lambda (port)
                (format port "#!/bin/sh~%~
export XKB_DEFAULT_LAYOUT=~a~%~
export XKB_DEFAULT_OPTIONS=~a~%~
exec ~a -c ~a~%"
                        #$%xkb-layout #$%xkb-options
                        #$(file-append river-0.4 "/bin/river") init)))
            (chmod start #o555)

            (call-with-output-file (string-append sessions "/sill.desktop")
              (lambda (port)
                (format port "[Desktop Entry]~%~
Name=sill~%~
Comment=river, with sill as the window manager~%~
Exec=~a~%~
Type=Application~%~
DesktopNames=sill~%"
                        start)))))))
    (home-page "https://codeberg.org/river/river")
    (synopsis "Wayland session entry for sill on river")
    (description "A wayland-sessions entry that starts river with sill as its
window manager, so a display manager offers it beside the others.")
    (license license:expat)))
