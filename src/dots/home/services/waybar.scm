(define-module (dots home services waybar)
  #:use-module (guix gexp)
  #:use-module (ice-9 format)
  #:use-module (dots theme base)
  #:use-module (dots config css)
  #:export (waybar-style
            waybar-capability))

(define (waybar-style theme)
  (define (c role) (theme-color theme role))
  (define radpx (string-append (number->string (shape-radius (theme-shape theme))) "px"))
  (css
   `(("*" (font-family . (\, (format #f "~s, monospace" (fonts-mono (theme-fonts theme)))))
      (font-size . "14px"))
     ("window#waybar" (background-color . ,(c 'bg)) (color . ,(c 'fg))
      (transition . "background-color 0.2s"))
     ("#workspaces button" (background-color . ,(c 'bg-alt)) (color . ,(c 'fg))
      (padding . "0 10px") (margin . "4px 2px") (border-radius . ,radpx))
     ("#workspaces button.focused, #workspaces button.active"
      (background-color . ,(c 'accent)) (color . ,(c 'accent-fg)))
     ("#workspaces button:hover"
      (background-color . ,(c 'bg-active)) (color . ,(c 'bright-white)))
     ("#clock, #battery" (background-color . ,(c 'bg-alt)) (color . ,(c 'green))
      (padding . "0 10px") (border-radius . ,radpx))
     ("#pulseaudio" (background-color . ,(c 'bg-alt)) (color . ,(c 'yellow))
      (padding . "0 10px") (border-radius . ,radpx))
     ("#network" (background-color . ,(c 'bg-alt)) (color . ,(c 'cyan))
      (padding . "0 10px") (border-radius . ,radpx))
     ("#battery.charging" (color . ,(c 'bright-green)))
     ("#battery.critical:not(.charging)"
      (background-color . ,(c 'red)) (color . ,(c 'bright-white))))))

(define (waybar-capability theme)
  "Return a home-xdg-configuration-files entry for the waybar style themed
from THEME."
  `(("waybar/style.css"
     ,(plain-file "waybar-style.css" (waybar-style theme)))))
