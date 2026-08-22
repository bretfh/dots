;;; fuzzel (application picker / dmenu) config generated from a <theme>. fuzzel
;;; uses an INI file with RRGGBBAA colours; the palette and mono font are
;;; injected from the theme. Returns home-xdg-configuration-files entries.

(define-module (dots desktop fuzzel)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (ice-9 format)
  #:use-module (dots theme base)
  #:use-module (dots config ini)
  #:use-module (dots core)
  #:use-module (dots desktop)
  #:export (fuzzel-config
            <fuzzel> fuzzel))

(define* (fuzzel-config theme #:key terminal)
  "Return the fuzzel.ini contents themed from THEME.  TERMINAL is the command
that runs a program in a terminal, e.g. \"alacritty -e\"."
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
           (terminal . ,(or terminal "")))
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

(define-class <fuzzel> (<picker>))
(define fuzzel (make <fuzzel> #:name 'fuzzel))

(define-method (component-layers (c <fuzzel>))
  '(("launcher" (radius . 0) (blur? . #t))))

(define-method (component-config-files (c <fuzzel>) desktop)
  `(("fuzzel/fuzzel.ini"
     ,(plain-file "fuzzel.ini"
                  (fuzzel-config (desktop-theme desktop)
                                 #:terminal (desktop-terminal-exec desktop))))))
