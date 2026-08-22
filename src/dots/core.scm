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

(define-module (dots core)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (dots theme base)
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
))



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
