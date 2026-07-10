;;; fuzzel (application picker / dmenu) config generated from a <theme>. fuzzel
;;; uses an INI file with RRGGBBAA colours; the palette and mono font are
;;; injected from the theme. Returns home-xdg-configuration-files entries.

(define-module (dots home services fuzzel)
  #:use-module (guix gexp)
  #:use-module (ice-9 format)
  #:use-module (dots theme base)
  #:use-module (dots config ini)
  #:export (fuzzel-config
            fuzzel-capability))

(define (fuzzel-config theme)
  "Return the fuzzel.ini contents themed from THEME."
  (define (rgba role alpha)
    (string-append (substring (theme-color theme role) 1) alpha))
  (define font (theme-fonts theme))
  (define shape (theme-shape theme))
  (ini
   `((main (font . ,(format #f "~a:size=~a" (fonts-mono font) (fonts-size font)))
           (prompt . "\"  \"")
           (width . 32)
           (lines . 12)
           (layer . overlay)
           (terminal . "alacritty -e"))
     (colors (background . ,(rgba 'bg (alpha-hex (shape-opacity shape))))
             (text . ,(rgba 'fg "ff"))
             (prompt . ,(rgba 'accent "ff"))
             (placeholder . ,(rgba 'fg-dim "ff"))
             (input . ,(rgba 'fg "ff"))
             (match . ,(rgba 'cyan "ff"))
             (selection . ,(rgba 'accent "ff"))
             (selection-text . ,(rgba 'accent-fg "ff"))
             (selection-match . ,(rgba 'accent-fg "ff"))
             (counter . ,(rgba 'fg-dim "ff"))
             (border . ,(rgba 'border "ff")))
     (border (width . ,(shape-border shape))
             (radius . ,(shape-radius shape))))))

(define (fuzzel-capability theme)
  "Return home-xdg-configuration-files entries for fuzzel themed from THEME."
  `(("fuzzel/fuzzel.ini"
     ,(plain-file "fuzzel.ini" (fuzzel-config theme)))))
