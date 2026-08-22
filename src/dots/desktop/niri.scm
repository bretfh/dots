(define-module (dots desktop niri)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (guix gexp)
  #:use-module (dots theme base)
  #:use-module (dots core)
  #:use-module (dots desktop)
  #:use-module (dots input)
  #:use-module (dots config kdl)
  #:export (niri-config
            keybind
            <niri> niri))


;;; keybind: build's one KDL bind node, ie (Mod+Return (spawn-sh "alacritty")).
;;; #:run CMD is sugar for the spawn-sh action; #:act gives any other action
;;; node directly (e.g. '(close-window) or '(set-column-width "-10%")).
(define* (keybind #:key (mod "") key run act locked)
  (let ((name (if (string-null? mod) key (string-append mod "+" key)))
        (action (if run (list 'spawn-sh run) act)))
    (if locked
        (list name '(@ (allow-when-locked true)) action)
        (list name action))))


;;; The binds that open something. What they open is whatever fills the role,
;;; so these keys can never disagree with the rest of the session.
(define (launch-bindings desktop)
  (filter-map
   (lambda (spec)
     (match spec
       ((mod key component)
        (and component
             (keybind #:mod mod #:key key #:run (component-launch component))))))
   (list (list "Mod" "Return" (desktop-terminal desktop))
         (list "Mod" "D"      (desktop-picker desktop))
         (list "Mod" "E"      (desktop-editor desktop))
         (list "Mod" "W"      (desktop-wallpaper desktop)))))

;;; Reloading the session means telling every program that can reload to do so.
(define (reload-binding desktop)
  (keybind #:mod "Mod+Shift" #:key "R"
           #:run (desktop-reload-command desktop)))

(define %niri-base-bindings
  (list
   ;; session
   (keybind #:mod "Mod" #:key "Q" #:act '(close-window))
   (keybind #:mod "Mod+Shift" #:key "E" #:act '(quit))
   (keybind #:mod "Mod" #:key "O" #:act '(toggle-overview))
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

(define (niri-bindings desktop)
  (append (launch-bindings desktop)
          (list (reload-binding desktop))
          %niri-base-bindings
          (numbered-workspace-bindings)))

;;; What the session spawns at login. Every entry comes from a component that
;;; said it autostarts, so this list never names a program: swap the bar and
;;; the startup follows. The dbus line is not a component -- it hands the
;;; session identity to dbus-activated services and must run first.
(define (niri-startups desktop)
  (cons (format #f "dbus-update-activation-environment --systemd \
WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=~a"
                (desktop-xdg-name desktop))
        (desktop-autostarts desktop)))

;;; config sections, as kdl nodes
(define (input-node kbd)
  `(input
    (keyboard (xkb (layout ,(keyboard-layout kbd))
                   (options ,(keyboard-options-string kbd))))
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

;;; Real compositor blur behind the session's layer-shell surfaces. Which
;;; namespaces those are is not niri's business -- every component declares
;;; the surfaces it puts on screen and this turns each into one rule, so the
;;; compositor config names no other program.
;;;
;;; A blurred surface is square (radius 0) so its outer edges meet the screen
;;; and each other seamlessly; rounding is done in CSS. `xray false' blurs the
;;; real content below the surface (the wallpaper layer and windows), not
;;; niri's empty transparent backdrop. It costs nothing here: the bar and echo
;;; are exclusive, so only the wallpaper is ever behind them, and niri blurs
;;; that once and reuses it.
;;;
;;; A surface that IS rounded (an overlay popup) needs its blur clipped to the
;;; same radius as its CSS corners, or a square blur boxes it off.
(define (layer-rule-node layer)
  (match layer
    ((namespace . props)
     (let ((on     (assq-ref props 'layer))
           (radius (or (assq-ref props 'radius) 0))
           (blur?  (assq-ref props 'blur?)))
       `(layer-rule
         (match (@ (namespace ,namespace)
                   ,@(if on `((layer ,on)) '())))
         (geometry-corner-radius ,radius)
         ,@(if blur?
               '((background-effect (blur true) (xray false)))
               '()))))))

(define (niri-intro)
  "// GENERATED ")

(define (niri-config desktop)
  "Return the list of kdl nodes for DESKTOP's niri config."
  (let ((theme (desktop-theme desktop)))
    (append
     (list (input-node (desktop-keyboard desktop))
           (layout-node theme)
           (overview-node theme)
           '(hotkey-overlay (skip-at-startup))
           '(prefer-no-csd)
           (list 'screenshot-path "~/pictures/screenshots/screen-%Y-%m-%d-%H-%M-%S.png")
           '(animations (slowdown 1.0))
           (cons 'binds (niri-bindings desktop))
           (window-rule-node theme))
     (map layer-rule-node (desktop-layers desktop))
     (map (lambda (cmd) (list 'spawn-sh-at-startup cmd))
          (niri-startups desktop)))))


;;; the component

(define-class <niri> (<compositor>))
(define niri (make <niri> #:name 'niri))

(define-method (component-launch (c <niri>)) "niri --session")
(define-method (component-reload (c <niri>)) "niri msg action load-config-file")
(define-method (component-quit   (c <niri>)) "niri msg action quit")

(define-method (component-config-files (c <niri>) desktop)
  `(("niri/config.kdl"
     ,(plain-file "config.kdl"
                  (string-append (niri-intro) "\n"
                                 (kdl (niri-config desktop)))))))
