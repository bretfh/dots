;;; alacritty config generated from a <theme>: the full 16-colour ANSI
;;; palette plus primary background/foreground, cursor, and the theme's
;;; mono font. Returns home-xdg-configuration-files entries.

(define-module (dots home services alacritty)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (dots theme base)
  #:use-module (dots config toml)
  #:use-module (dots home component)
  #:export (alacritty-config
            <alacritty> alacritty))

(define (alacritty-config theme)
  "Return the alacritty.toml contents themed from THEME."
  (define (c role) (theme-color theme role))
  (define font (theme-fonts theme))
  (toml
   `((font          (size . ,(fonts-size font)))
     (font.normal   (family . ,(fonts-mono font)))
     (colors.primary (background . ,(c 'bg)) (foreground . ,(c 'fg)))
     (colors.cursor  (text . ,(c 'bg)) (cursor . ,(c 'cursor)))
     (colors.normal  (black . ,(c 'black)) (red . ,(c 'red))
                     (green . ,(c 'green)) (yellow . ,(c 'yellow))
                     (blue . ,(c 'blue)) (magenta . ,(c 'magenta))
                     (cyan . ,(c 'cyan)) (white . ,(c 'white)))
     (colors.bright  (black . ,(c 'bright-black)) (red . ,(c 'bright-red))
                     (green . ,(c 'bright-green)) (yellow . ,(c 'bright-yellow))
                     (blue . ,(c 'bright-blue)) (magenta . ,(c 'bright-magenta))
                     (cyan . ,(c 'bright-cyan)) (white . ,(c 'bright-white))))))

(define-class <alacritty> (<terminal>))
(define alacritty (make <alacritty> #:name 'alacritty))

;; `alacritty -e CMD' is how a picker hands a command to this terminal.
(define-method (component-exec-flag (c <alacritty>)) "-e")

(define-method (component-config-files (c <alacritty>) desktop)
  `(("alacritty/alacritty.toml"
     ,(plain-file "alacritty.toml"
                  (alacritty-config (desktop-theme desktop))))))
