;;; A desktop component is a program that fills one role in the session -- a
;;; compositor, a bar, a picker, a terminal, an editor. Each one answers the
;;; same set of questions, so nothing that uses a component ever asks which
;;; program it is: it asks the component.
;;;
;;; Every question is a generic with a default on <component>, so a program
;;; defines only what differs from the default. Role classes carry defaults
;;; too -- a <bar> autostarts, a <terminal> does not -- so most programs are
;;; a class, a value, and one or two methods, written beside the config
;;; generator they already have in (dots home services NAME).
;;;
;;; <desktop> collects them: one list per role, head is the primary and the
;;; tail are fallbacks. Fallbacks stay installed and keep their generated
;;; config; only the primary is launched, autostarted, and owns daemons.
;;;
;;; Two ways to get this wrong, both silent:
;;;
;;;   - a generic is defined ONCE, here. Program modules import it and only
;;;     ever `define-method'. A second `define-generic' of the same name makes
;;;     a distinct generic, and dispatch splits with no error.
;;;
;;;   - a method must take the same number of arguments as the default below.
;;;     A `(define-method (component-autostart (c <emacs>)) ...)' against a
;;;     two-argument generic is not an override, it is an unrelated method that
;;;     never runs -- the default fires instead and the program quietly drops
;;;     out of the startup list. Check the arity against the defaults here.

(define-module (dots home component)
  #:use-module (oop goops)
  #:use-module (guix records)
  #:use-module (srfi srfi-1)
  #:use-module (dots theme base)
  #:use-module (dots theme ef-dream)
  #:export (<component> <compositor> <bar> <picker> <terminal> <editor>
            <notifier> <lock> <idle> <wallpaper> <toolkit>
            component-name
            component-launch
            component-command
            component-exec-flag
            component-autostart
            component-reload
            component-packages
            component-config-files
            component-services
            component-xdg-name
            component-gtk-css
            component-layers
            component-quit

            keyboard keyboard?
            keyboard-layout keyboard-options keyboard-options-string
            %default-keyboard

            desktop desktop?
            desktop-compositors desktop-bars desktop-pickers
            desktop-terminals desktop-editors desktop-theme desktop-keyboard
            desktop-notifiers desktop-locks desktop-idlers
            desktop-wallpapers desktop-toolkits
            desktop-compositor desktop-bar desktop-picker
            desktop-terminal desktop-editor
            desktop-notifier desktop-lock desktop-idler
            desktop-wallpaper desktop-toolkit
            desktop-all desktop-primaries
            desktop-xdg-name
            desktop-terminal-exec
            desktop-packages
            desktop-config-files
            desktop-services
            desktop-autostarts
            desktop-reload-command
            desktop-gtk-css
            desktop-layers))


;;; the component classes: one root, one class per role of <desktop>

(define-class <component> ()
  (name #:init-keyword #:name #:getter component-name))

(define-class <compositor> (<component>))
(define-class <bar>        (<component>))
(define-class <picker>     (<component>))
(define-class <terminal>   (<component>))
(define-class <editor>     (<component>))
(define-class <notifier>   (<component>))   ; mako
(define-class <lock>       (<component>))   ; gtklock
(define-class <idle>       (<component>))   ; swayidle
(define-class <wallpaper>  (<component>))   ; swaybg
(define-class <toolkit>    (<component>))   ; gtk -- skins apps, runs nothing


;;; the questions. One generic each, each with a default, so adding a question
;;; later needs no edit to any existing component.

(define-generic component-launch)
(define-generic component-command)
(define-generic component-exec-flag)
(define-generic component-autostart)
(define-generic component-reload)
(define-generic component-packages)
(define-generic component-config-files)
(define-generic component-services)
(define-generic component-xdg-name)
(define-generic component-gtk-css)
(define-generic component-layers)
(define-generic component-quit)

(define-method (component-launch (c <component>))
  "The command that starts C in a live session."
  (symbol->string (component-name c)))

(define-method (component-command (c <component>))
  "C as a command for another program to invoke -- $EDITOR, fuzzel's terminal.
Defaults to the launch command; editors that need a terminal frame differ."
  (component-launch c))

(define-method (component-exec-flag (c <component>))
  "The flag that makes C run a given command instead of a shell.  Terminals
answer this; nothing else does."
  #f)

(define-method (component-autostart (c <component>) desktop)
  "The command to spawn when the session starts, or #f for on-demand programs.
Takes the desktop because a startup line may name another role -- the idle
watcher has to know what locks the session."
  #f)

(define-method (component-reload (c <component>))
  "The command that makes C re-read its config, or #f."
  #f)

(define-method (component-packages (c <component>))
  "Guix package specifications or objects to install for C.  Programs that come
from a service extension or a working tree answer '()."
  (list (symbol->string (component-name c))))

(define-method (component-config-files (c <component>) desktop)
  "home-xdg-configuration-files entries for C, generated from DESKTOP."
  '())

(define-method (component-services (c <component>) desktop)
  "Guix services C needs -- shepherd daemons, profile extensions.  Only the
primary of a role is asked, so demoting a program stops its daemon."
  '())

(define-method (component-xdg-name (c <component>))
  "C's XDG_CURRENT_DESKTOP value."
  (symbol->string (component-name c)))

(define-method (component-gtk-css (c <component>))
  "A GTK3 rule C needs for its own widgets, or #f.  Lets a program carry its
own quirk instead of the toolkit knowing every program's widget names."
  #f)

(define-method (component-quit (c <component>))
  "The command that ends the session, or #f.  Compositors answer this."
  #f)

(define-method (component-layers (c <component>))
  "The wayland layer-shell surfaces C puts on screen, so the compositor can
give them blur and corners without knowing which program owns them.  Each is
(NAMESPACE (layer . L) (radius . R) (blur? . B)); layer and blur? optional."
  '())

;;; Role defaults. A bar, a notifier, an idle watcher and a wallpaper are part
;;; of the session and come up with it; a terminal, picker, editor or lock is
;;; invoked on demand.
(define-method (component-autostart (c <bar>) d)       (component-launch c))
(define-method (component-autostart (c <notifier>) d)  (component-launch c))
(define-method (component-autostart (c <idle>) d)      (component-launch c))
(define-method (component-autostart (c <wallpaper>) d) (component-launch c))

;;; A toolkit is not a program: it skins other applications and nothing else.
(define-method (component-packages (c <toolkit>)) '())
(define-method (component-launch   (c <toolkit>)) #f)


;;; <keyboard>: the xkb declaration, once. It was spelled out separately for
;;; niri, for the pine session entry, and for the system's console layout.

(define-record-type* <keyboard> keyboard make-keyboard
  keyboard?
  (layout  keyboard-layout  (default "us"))
  (options keyboard-options (default '("ctrl:swapcaps"))))

(define (keyboard-options-string k)
  "XKB_DEFAULT_OPTIONS / niri `options' form: comma-separated."
  (string-join (keyboard-options k) ","))

;;; Caps lock is another control. Read by the niri config, by the pine session
;;; entry's XKB_DEFAULT_*, and by the system's console layout, which each used
;;; to say it separately.
(define %default-keyboard
  (keyboard (layout "us") (options '("ctrl:swapcaps"))))


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
  (theme       desktop-theme       (default ef-dream))
  (keyboard    desktop-keyboard    (default %default-keyboard)))

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
