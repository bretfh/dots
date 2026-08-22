;;; <desktop> -- the single declaration of the session: which tools fill each
;;; role and which theme and keyboard they share. Each role is a SET whose head
;;; is the primary and whose tail are fallbacks. The primary drives keybinds,
;;; env, launch commands, autostart and daemons; fallbacks stay installed and
;;; keep their generated config, so promoting one is reordering a list.
;;;
;;; Nothing here says how any of these programs works. Each answers for itself
;;; in (dots desktop NAME) -- see (dots core) for the questions
;;; a component can be asked. Adding a program is a class and its methods in
;;; one module, plus its name in one list below.

(define-module (dots desktop)
  #:use-module (dots core)
  #:use-module (dots input)
  #:use-module (dots theme ef-dream)
  #:use-module (dots desktop niri)
  #:use-module (dots desktop pine)
  #:use-module (dots desktop eww)
  #:use-module (dots desktop waybar)
  #:use-module (dots desktop fuzzel)
  #:use-module (dots desktop alacritty)
  #:use-module (dots desktop emacs)
  #:use-module (dots desktop mako)
  #:use-module (dots desktop gtklock)
  #:use-module (dots desktop gtk)
  #:use-module (dots desktop sway)
  #:use-module (dots desktop wezterm)
  #:use-module (dots desktop vim)
  #:use-module (dots desktop swaybg)
  #:use-module (dots desktop swayidle)
  #:export (default-desktop))

(define default-desktop
  (desktop
   (compositors (list niri sway))
   (bars        (list pine eww waybar))
   (pickers     (list fuzzel))
   (terminals   (list alacritty wezterm))
   (editors     (list emacs vim))
   (notifiers   (list mako))
   (locks       (list gtklock))
   (idlers      (list swayidle))
   (wallpapers  (list swaybg))
   (toolkits    (list gtk))
   (theme       ef-dream)
   (keyboard    %default-keyboard)))
