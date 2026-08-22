;;; <desktop> -- the single declaration of the session: which tools fill each
;;; role and which theme and keyboard they share. Each role is a SET whose head
;;; is the primary and whose tail are fallbacks. The primary drives keybinds,
;;; env, launch commands, autostart and daemons; fallbacks stay installed and
;;; keep their generated config, so promoting one is reordering a list.
;;;
;;; Nothing here says how any of these programs works. Each answers for itself
;;; in (dots home services NAME) -- see (dots home component) for the questions
;;; a component can be asked. Adding a program is a class and its methods in
;;; one module, plus its name in one list below.

(define-module (dots home desktop)
  #:use-module (dots home component)
  #:use-module (dots theme ef-dream)
  #:use-module (dots home services niri)
  #:use-module (dots home services pine)
  #:use-module (dots home services eww)
  #:use-module (dots home services waybar)
  #:use-module (dots home services fuzzel)
  #:use-module (dots home services alacritty)
  #:use-module (dots home services emacs)
  #:use-module (dots home services mako)
  #:use-module (dots home services gtklock)
  #:use-module (dots home services gtk)
  #:use-module (dots home services sway)
  #:use-module (dots home services wezterm)
  #:use-module (dots home services vim)
  #:use-module (dots home services swaybg)
  #:use-module (dots home services swayidle)
  #:re-export (desktop desktop?
               desktop-compositors desktop-bars desktop-pickers
               desktop-terminals desktop-editors
               desktop-notifiers desktop-locks desktop-idlers
               desktop-wallpapers desktop-toolkits
               desktop-theme desktop-keyboard
               desktop-compositor desktop-bar desktop-picker
               desktop-terminal desktop-editor
               desktop-notifier desktop-lock desktop-idler
               desktop-wallpaper desktop-toolkit
               desktop-all desktop-primaries
               desktop-xdg-name desktop-terminal-exec
               desktop-packages desktop-config-files desktop-services
               desktop-autostarts desktop-reload-command
               keyboard keyboard-layout keyboard-options %default-keyboard
               component-launch component-command)
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
