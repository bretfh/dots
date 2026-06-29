;;; gtklock (session lockscreen) themed from a <theme>: a glib-keyfile config
;;; (config.ini, [main]), a GTK stylesheet (style.css), and a launch wrapper
;;; that blurs and dims the live wallpaper into a cache image and hands it to
;;; gtklock as the background, so the lock is the same frosted glass as the
;;; rest of the desktop. Returns home-xdg-configuration-files entries.

(define-module (dots home services gtklock)
  #:use-module (guix gexp)
  #:use-module (dots theme base)
  #:use-module (dots config ini)
  #:use-module (dots config css)
  #:export (gtklock-config
            gtklock-style
            gtklock-lock
            gtklock-capability))

(define (gtklock-config theme)
  "Return the gtklock config.ini contents themed from THEME."
  (ini
   `((main (time-format . "%H:%M")
           (date-format . "%A, %B %-d")))))

(define (gtklock-style theme)
  "Return the gtklock style.css themed from THEME.  The window background is the
blurred wallpaper (set by the launch wrapper); the panel is the shared glass."
  (define (c role) (theme-color theme role))
  (define shape (theme-shape theme))
  (define rad   (string-append (number->string (shape-radius shape)) "px"))
  (define mono  (fonts-mono (theme-fonts theme)))
  (define glass (hex->rgba (c 'bg-dim) (shape-opacity shape)))
  (css
   `(("window" (font-family . ,(string-append "\"" mono "\"")))
     ("#window-box" (background-color . ,glass) (border-radius . ,rad)
                    (border-width . "1px") (border-style . "solid")
                    (border-color . ,(c 'border))
                    (padding . "48px 64px") (margin-right . "360px"))
     ("#clock-label" (color . ,(c 'fg)) (font-size . "76px") (font-weight . "bold"))
     ("#date-label"  (color . ,(c 'fg-dim)) (font-size . "22px") (margin-bottom . "28px"))
     ("#input-field" (background-color . ,(c 'bg-alt)) (color . ,(c 'fg))
                     (border-width . "1px") (border-style . "solid")
                     (border-color . ,(c 'border))
                     (border-radius . ,rad) (padding . "10px 16px")
                     (margin-top . "24px") (min-width . "260px"))
     ("#input-field:focus" (border-color . ,(c 'accent)))
     ("#unlock-button" (background-color . ,(c 'accent)) (color . ,(c 'accent-fg))
                       (border-radius . ,rad) (padding . "10px 18px") (margin-top . "12px"))
     ("#error-label, #warning-label" (color . ,(c 'red))))))

;; POSIX sh: blur+dim the live wallpaper, exec gtklock with it as background.
(define gtklock-lock
  "#!/bin/sh
style=\"$HOME/.config/gtklock/style.css\"
out=\"${XDG_CACHE_HOME:-$HOME/.cache}/gtklock-bg.png\"
bg=$(pgrep -af swaybg 2>/dev/null | sed -n 's/.* -i \\([^ ]*\\).*/\\1/p' | head -1)
if [ -n \"$bg\" ] && command -v convert >/dev/null 2>&1; then
  convert \"$bg\" -resize 60% -blur 0x16 -fill black -colorize 30% \"$out\" 2>/dev/null
fi
if [ -f \"$out\" ]; then exec gtklock -s \"$style\" -b \"$out\" \"$@\"; fi
exec gtklock -s \"$style\" \"$@\"
")

(define (gtklock-capability theme)
  "Return home-xdg-configuration-files entries for gtklock themed from THEME."
  `(("gtklock/config.ini" ,(plain-file "gtklock-config.ini" (gtklock-config theme)))
    ("gtklock/style.css"  ,(plain-file "gtklock-style.css"  (gtklock-style theme)))
    ("gtklock/lock"       ,(plain-file "gtklock-lock"       gtklock-lock))))
