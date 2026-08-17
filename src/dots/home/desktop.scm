;;; <desktop> -- the single declaration of the session: which tools fill each
;;; role and which theme they share. Each role is a SET whose head is the
;;; primary and whose tail are fallbacks. The primary drives keybinds, env,
;;; launch commands, and the theme-generated config; fallbacks are kept
;;; installed and available with their own (static) config. Package installs
;;; for the user-facing tools derive from these sets, so one place lists every
;;; desktop tool and which is in use.

(define-module (dots home desktop)
  #:use-module (guix records)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (dots theme base)
  #:use-module (dots theme ef-dream)
  #:export (desktop desktop?
            desktop-compositors desktop-bars desktop-pickers
            desktop-terminals desktop-editors desktop-theme
            desktop-compositor desktop-bar desktop-picker
            desktop-terminal desktop-editor
            desktop-xdg-name
            desktop-launch-terminal desktop-launch-picker
            desktop-launch-editor desktop-launch-bar
            desktop-launch-compositor
            desktop-editor-command
            desktop-packages
            default-desktop))

(define-record-type* <desktop> desktop make-desktop
  desktop?
  (compositors desktop-compositors (default '(niri sway)))
  (bars        desktop-bars        (default '(eww waybar)))
  (pickers     desktop-pickers     (default '(fuzzel)))
  (terminals   desktop-terminals   (default '(alacritty wezterm)))
  (editors     desktop-editors     (default '(emacs vim)))
  (theme       desktop-theme       (default ef-dream)))

(define (desktop-compositor d)
  "Return D's primary compositor."
  (car (desktop-compositors d)))

(define (desktop-bar d)
  "Return D's primary status bar."
  (car (desktop-bars d)))

(define (desktop-picker d)
  "Return D's primary application picker."
  (car (desktop-pickers d)))

(define (desktop-terminal d)
  "Return D's primary terminal."
  (car (desktop-terminals d)))

(define (desktop-editor d)
  "Return D's primary editor."
  (car (desktop-editors d)))

(define (desktop-xdg-name d)
  "Return the XDG_CURRENT_DESKTOP value for D's primary compositor."
  (symbol->string (desktop-compositor d)))

(define (desktop-launch-terminal d)
  "Return the shell command that opens D's terminal."
  (match (desktop-terminal d)
    ('alacritty "alacritty")
    (other (symbol->string other))))

(define (desktop-launch-picker d)
  "Return the shell command that opens D's application picker."
  (match (desktop-picker d)
    ('fuzzel "fuzzel")
    ('wofi "wofi --show=drun")
    ('rofi "rofi -show drun")
    (other (symbol->string other))))

(define (desktop-launch-editor d)
  "Return the shell command that opens D's editor as a window.  For emacs this
connects to the emacs-daemon home service (never spawns a competing instance --
`-a emacs' did, which is why Mod+E opened a fresh Emacs)."
  (match (desktop-editor d)
    ('emacs "emacsclient -c")
    (other (symbol->string other))))

(define (desktop-editor-command d)
  "Return the EDITOR/VISUAL value for D's editor (a terminal-capable command
suitable for tools that spawn $EDITOR)."
  (match (desktop-editor d)
    ('emacs "emacsclient -t")
    (other (symbol->string other))))

(define (desktop-launch-bar d)
  (match (desktop-bar d)
    ('eww "eww open-many echo bar")
    ('pine (string-append
            "cd $HOME/git/cl/pine && exec guix shell -m manifest.scm -- sh -c "
            "'LD_LIBRARY_PATH=\"$GUIX_ENVIRONMENT/lib\" "
            "ASDF_OUTPUT_TRANSLATIONS=\"/:$HOME/.cache/common-lisp/pine/\" "
            "exec sbcl --non-interactive "
            "--eval \"(asdf:load-system :pine/wayflan)\" "
            "--eval \"(pine.wayland:run-desktop)\"'"))
    (other (symbol->string other))))

(define (desktop-launch-compositor d)
  "Return the command that starts D's compositor as a login session, used by
the bare-tty1 fallback when no display manager handed off a session."
  (match (desktop-compositor d)
    ('niri "niri --session")
    ('sway "sway")
    (other (symbol->string other))))

(define (tool->package tool)
  "Return the guix package specification for TOOL, or #f when TOOL is provided
some other way (emacs ships from its own home service)."
  (match tool
    ('emacs #f)
    ('pine  #f)
    (other (symbol->string other))))

(define (desktop-packages d)
  "Return guix package specifications for D's user-facing tools -- bars,
pickers, terminals, editors -- primary and fallbacks alike.  Compositors are
session infrastructure installed at the system level, so they are not here."
  (filter-map tool->package
              (append (desktop-bars d) (desktop-pickers d)
                      (desktop-terminals d) (desktop-editors d))))

(define default-desktop
  (desktop
   (compositors '(niri sway))
   (bars        '(pine eww waybar))
   (pickers     '(fuzzel))
   (terminals   '(alacritty wezterm))
   (editors     '(emacs vim))
   (theme       ef-dream)))
