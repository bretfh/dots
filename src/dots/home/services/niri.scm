(define-module (dots home services niri)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:use-module (guix gexp)
  #:use-module (dots theme base)
  #:use-module (dots home desktop)
  #:use-module (dots config kdl)
  #:export (niri-capability
            niri-config
            keybind
            default-niri-bindings
            default-niri-startups
            default-niri-xkb-options))


;;; keybind: build's one KDL bind node, ie (Mod+Return (spawn-sh "alacritty")).
;;; #:run CMD is sugar for the spawn-sh action; #:act gives any other action
;;; node directly (e.g. '(close-window) or '(set-column-width "-10%")).
(define* (keybind #:key (mod "") key run act locked)
  (let ((name (if (string-null? mod) key (string-append mod "+" key)))
        (action (if run (list 'spawn-sh run) act)))
    (if locked
        (list name '(@ (allow-when-locked true)) action)
        (list name action))))


;;; default binding set
(define (desktop-launch-bindings desktop)
  "Return the niri keybindings that launch DESKTOP's terminal, picker, and
editor, so the keys agree with the rest of the session."
  (list
   (keybind #:mod "Mod" #:key "Return" #:run (desktop-launch-terminal desktop))
   (keybind #:mod "Mod" #:key "D" #:run (desktop-launch-picker desktop))
   (keybind #:mod "Mod" #:key "E" #:run (desktop-launch-editor desktop))))

(define %niri-base-bindings
  (list
   ;; session
   (keybind #:mod "Mod" #:key "Q" #:act '(close-window))
   (keybind #:mod "Mod+Shift" #:key "E" #:act '(quit))
   (keybind #:mod "Mod" #:key "O" #:act '(toggle-overview))
   (keybind #:mod "Mod" #:key "W" #:run "bash ~/.config/rice/wallpaper")
   (keybind #:mod "Mod+Shift" #:key "R"
            #:run "niri msg action load-config-file; eww reload; makoctl reload")

   ;; focus: Mod+H/L between columns, Mod+J/K within a column
   (keybind #:mod "Mod" #:key "H" #:act '(focus-column-left))
   (keybind #:mod "Mod" #:key "L" #:act '(focus-column-right))
   (keybind #:mod "Mod" #:key "J" #:act '(focus-window-down))
   (keybind #:mod "Mod" #:key "K" #:act '(focus-window-up))

   ;; move
   (keybind #:mod "Mod+Shift" #:key "H" #:act '(move-column-left))
   (keybind #:mod "Mod+Shift" #:key "L" #:act '(move-column-right))
   (keybind #:mod "Mod+Shift" #:key "J" #:act '(move-window-down))
   (keybind #:mod "Mod+Shift" #:key "K" #:act '(move-window-up))

   ;; column composition
   (keybind #:mod "Mod" #:key "comma" #:act '(consume-window-into-column))
   (keybind #:mod "Mod" #:key "period" #:act '(expel-window-from-column))
   (keybind #:mod "Mod" #:key "C" #:act '(center-column))

   ;; column width / fullscreen
   (keybind #:mod "Mod" #:key "R" #:act '(switch-preset-column-width))
   (keybind #:mod "Mod" #:key "F" #:act '(maximize-column))
   (keybind #:mod "Mod+Shift" #:key "F" #:act '(fullscreen-window))
   (keybind #:mod "Mod" #:key "minus" #:act '(set-column-width "-10%"))
   (keybind #:mod "Mod" #:key "equal" #:act '(set-column-width "+10%"))

   ;; floating
   (keybind #:mod "Mod" #:key "space" #:act '(toggle-window-floating))
   (keybind #:mod "Mod+Shift" #:key "space" #:act '(switch-focus-between-floating-and-tiling))

   ;; workspace cycle
   (keybind #:mod "Mod" #:key "Page_Down" #:act '(focus-workspace-down))
   (keybind #:mod "Mod" #:key "Page_Up" #:act '(focus-workspace-up))

   ;; screenshot
   (keybind #:key "Print" #:act '(screenshot))
   (keybind #:mod "Mod" #:key "Print" #:act '(screenshot-screen))
   (keybind #:mod "Mod+Shift" #:key "Print" #:act '(screenshot-window))

   ;; brightness / audio
   (keybind #:key "XF86MonBrightnessUp" #:locked #t #:run "brightnessctl s +10%")
   (keybind #:key "XF86MonBrightnessDown" #:locked #t #:run "brightnessctl s 10%-")
   (keybind #:key "XF86AudioRaiseVolume" #:locked #t #:run "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+")
   (keybind #:key "XF86AudioLowerVolume" #:locked #t #:run "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
   (keybind #:key "XF86AudioMute" #:locked #t #:run "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")))

(define (numbered-workspace-bindings)
  (append-map
   (lambda (n)
     (let ((k (if (= n 10) "0" (number->string n))))
       (list
        (keybind #:mod "Mod" #:key k #:act `(focus-workspace ,n))
        (keybind #:mod "Mod+Shift" #:key k #:act `(move-column-to-workspace ,n)))))
   (iota 10 1)))

(define default-niri-bindings
  (append (desktop-launch-bindings default-desktop)
          %niri-base-bindings
          (numbered-workspace-bindings)))

;;; default startup commands and xkb options
(define default-niri-startups
  (list (desktop-launch-bar default-desktop)
        "mako"
        (string-append "swayidle -w timeout 600 "
                       "'sh ~/.config/gtklock/lock -d' "
                       "before-sleep 'sh ~/.config/gtklock/lock -d'")
        (format #f "dbus-update-activation-environment --systemd \
WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=~a"
                (desktop-xdg-name default-desktop))
        ;; rebind the emacs daemon (a home shepherd service) to this session's
        ;; wayland display. this way, the persistent shepherd doesn't restart on login,
        ;; and pgtk emacs needs the live display to make gui frames.
        "herd restart emacs-daemon"
        "bash ~/.config/rice/wallpaper"))

(define default-niri-xkb-options "ctrl:swapcaps")

;;; config sections, as kdl nodes
(define (input-node keyboard-layout xkb-options)
  `(input
    (keyboard (xkb (layout ,keyboard-layout) (options ,(or xkb-options ""))))
    (touchpad (tap))
    (warp-mouse-to-focus)))

(define (layout-node theme)
  `(layout
    (background-color "transparent")
    (gaps ,(shape-gaps (theme-shape theme)))
    (center-focused-column "never")
    (preset-column-widths (proportion 0.333333) (proportion 0.5) (proportion 0.666666))
    (default-column-width (proportion 0.666666))
    (focus-ring (width ,(shape-border (theme-shape theme)))
                (active-color ,(theme-color theme 'accent))
                (inactive-color ,(theme-color theme 'bg-active)))
    (shadow (on) (softness 30) (spread 5) (offset (@ (x 0) (y 5))) (color "#0007"))
    (struts (left 4) (right 4) (top 4) (bottom 4))))

(define (overview-node theme)
  `(overview
    (zoom 0.5)
    (backdrop-color ,(theme-color theme 'bg-dim))
    (workspace-shadow (softness 40) (spread 10) (offset (@ (x 0) (y 10))) (color "#00000060"))))

(define (window-rule-node theme)
  `(window-rule
    (geometry-corner-radius ,(shape-radius (theme-shape theme)))
    (clip-to-geometry true)
    (draw-border-with-background false)))

;;; Real compositor blur behind the eww layer-shell surfaces. The bar, the echo
;;; strip, and every eww popup share the gtk-layer-shell namespace, so one rule
;;; gives them all the same glass. x-ray blur is the default and costs nothing
;;; here: the bar and echo are exclusive, so only the wallpaper is ever behind
;;; them, and niri blurs that once and reuses it.
(define (layer-rule-node theme)
  ;; Bar + echo are square (radius 0) so their outer edges meet the screen and
  ;; each other seamlessly; any rounding is done in CSS on the accent corner
  ;; box. xray false blurs the real content below the surface (the wallpaper
  ;; layer + windows), not niri's empty transparent backdrop.
  `(layer-rule
    (match (@ (namespace "gtk-layer-shell")))
    (match (@ (namespace "notifications")))
    (match (@ (namespace "launcher")))
    (geometry-corner-radius 0)
    (background-effect (blur true) (xray false))))

;;; The eww popups (network / audio / media / control) live on the overlay
;;; layer; keep their blur clipped to the same 20px radius as their CSS corners
;;; so the rounded popups are not boxed off by a square blur.
(define (layer-rule-popup-node theme)
  `(layer-rule
    (match (@ (namespace "gtk-layer-shell") (layer "overlay")))
    (geometry-corner-radius 20)))

(define (niri-intro)
  "// GENERATED ")

(define* (niri-config #:key theme keyboard-layout xkb-options
                      (bindings '()) (startups '()))
  "return the list of kdl nodes for the niri config."
  (append
   (list (input-node keyboard-layout xkb-options)
         (layout-node theme)
         (overview-node theme)
         '(hotkey-overlay (skip-at-startup))
         '(prefer-no-csd)
         (list 'screenshot-path "~/pictures/screenshots/screen-%Y-%m-%d-%H-%M-%S.png")
         '(animations (slowdown 1.0))
         (cons 'binds bindings)
         (window-rule-node theme)
         (layer-rule-node theme)
         (layer-rule-popup-node theme))
   (map (lambda (cmd) (list 'spawn-sh-at-startup cmd)) startups)))


;;; the home-files capability
(define* (niri-capability #:key theme
                          keyboard-layout
                          xkb-options
                          (bindings default-niri-bindings)
                          (startups default-niri-startups))
  `(("niri/config.kdl"
     ,(plain-file
       "config.kdl"
       (string-append
        (niri-intro) "\n"
        (kdl (niri-config #:theme theme
                          #:keyboard-layout keyboard-layout
                          #:xkb-options xkb-options
                          #:bindings bindings
                          #:startups startups)))))))
