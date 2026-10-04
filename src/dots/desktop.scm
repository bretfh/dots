(define-module (dots desktop)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:use-module (dots core)
  #:use-module (dots input)
  #:export (desktop desktop? desktop-all desktop-asset desktop-assets desktop-autostarts desktop-bar desktop-bars desktop-compositor desktop-compositors desktop-config-files desktop-editor desktop-editors desktop-environment desktop-gtk-css desktop-idler desktop-idlers desktop-keyboard desktop-layers desktop-lock desktop-locks desktop-login-script desktop-notifier desktop-notifiers desktop-packages desktop-picker desktop-pickers desktop-primaries desktop-reload-command desktop-roles desktop-services desktop-terminal desktop-terminal-exec desktop-terminals desktop-theme desktop-toolkit desktop-toolkits desktop-wallpaper desktop-wallpapers desktop-xdg-name))

;;; <desktop>: which programs fill each role, and the theme they share.

(define-record-type* <desktop> desktop make-desktop
  desktop?
  (compositors desktop-compositors (default '()))
  (bars        desktop-bars        (default '()))
  (pickers     desktop-pickers     (default '()))
  (terminals   desktop-terminals   (default '()))
  (editors     desktop-editors     (default '()))
  (notifiers   desktop-notifiers   (default '()))
  (locks       desktop-locks       (default '()))
  (idlers      desktop-idlers      (default '()))
  (wallpapers  desktop-wallpapers  (default '()))
  (toolkits    desktop-toolkits    (default '()))
  (theme       desktop-theme)
  (keyboard    desktop-keyboard    (default %default-keyboard))
  (assets      desktop-assets      (default #f)))

(define* (desktop-asset d rel #:key recursive?)
  "REL, a path under D's asset directory, as a local-file."
  (unless (desktop-assets d)
    (error "desktop has no assets directory" rel))
  (local-file (canonicalize-path (string-append (desktop-assets d) "/" rel))
              #:recursive? recursive?))

(define (desktop-roles d)
  "Return D's role lists, in declaration order.  Autostart order follows this
list, so the notifier and the bar come up before the wallpaper."
  (list (desktop-compositors d) (desktop-notifiers d) (desktop-bars d)
        (desktop-pickers d) (desktop-terminals d) (desktop-editors d)
        (desktop-locks d) (desktop-idlers d) (desktop-wallpapers d)
        (desktop-toolkits d)))

(define (desktop-all d)
  "Every component D declares, primary and fallback alike."
  (concatenate (desktop-roles d)))

(define (desktop-primaries d)
  "The head of each of D's role lists."
  (filter-map (lambda (role) (and (pair? role) (car role)))
              (desktop-roles d)))

(define (primary lst) (and (pair? lst) (car lst)))

(define (desktop-compositor d) (primary (desktop-compositors d)))
(define (desktop-bar        d) (primary (desktop-bars d)))
(define (desktop-picker     d) (primary (desktop-pickers d)))
(define (desktop-terminal   d) (primary (desktop-terminals d)))
(define (desktop-editor     d) (primary (desktop-editors d)))
(define (desktop-notifier   d) (primary (desktop-notifiers d)))
(define (desktop-lock       d) (primary (desktop-locks d)))
(define (desktop-idler      d) (primary (desktop-idlers d)))
(define (desktop-wallpaper  d) (primary (desktop-wallpapers d)))
(define (desktop-toolkit    d) (primary (desktop-toolkits d)))

(define (desktop-xdg-name d)
  (component-xdg-name (desktop-compositor d)))

(define (desktop-terminal-exec d)
  "Return the command prefix that runs another program inside D's terminal,
e.g. \"alacritty -e\".  This is what a picker hands off to."
  (let* ((t (desktop-terminal d))
         (flag (and t (component-exec-flag t))))
    (and t (if flag
               (string-append (component-launch t) " " flag)
               (component-launch t)))))


;;; the four things the home environment asks a whole desktop for. Each is an
;;; append-map over the components; none of them names a program.

(define (desktop-packages d)
  "Package specifications for every component D declares."
  (append-map component-packages (desktop-all d)))

(define (desktop-config-files d)
  "home-xdg-configuration-files entries for every component D declares, so a
fallback keeps its config and switching to it is a one-line change."
  (append-map (lambda (c) (component-config-files c d)) (desktop-all d)))

(define (desktop-services d)
  "Guix services for D's primaries only -- a demoted program's daemon stops
being declared."
  (append-map (lambda (c) (component-services c d)) (desktop-primaries d)))

(define (desktop-autostarts d)
  "The commands the compositor spawns at session start, in role order."
  (filter-map (lambda (c) (component-autostart c d)) (desktop-primaries d)))

(define (desktop-gtk-css d)
  "Extra GTK3 rules contributed by D's components."
  (filter-map component-gtk-css (desktop-all d)))

(define (desktop-layers d)
  "Every layer-shell surface D's components declare."
  (append-map component-layers (desktop-all d)))

(define (desktop-reload-command d)
  "One shell command that reloads every primary that can be reloaded."
  (string-join (filter-map component-reload (desktop-primaries d)) "; "))

(define (desktop-environment d)
  "Environment variables D's primaries put in every login shell."
  (append-map component-environment (desktop-primaries d)))

(define (desktop-login-script d)
  "What a login shell does on a bare tty1, where no display manager handed off
a session: set the identity that path lacks and start D's compositor."
  (format #f "\
if [ -z \"$DISPLAY\" ] && [ \"$(tty)\" = /dev/tty1 ]; then
    export XDG_CURRENT_DESKTOP=~a
    export XDG_SESSION_TYPE=wayland
    exec ~a
fi
"
          (desktop-xdg-name d)
          (component-launch (desktop-compositor d))))
