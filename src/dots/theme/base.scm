;;; <theme> record + accessors. A theme carries every visual token the
;;; desktop shares: a complete colour palette (semantic roles plus the 16
;;; ANSI terminal colours), fonts, and shape. Consumers (niri, alacritty,
;;; waybar, fuzzel) take a theme and pull what they need; no consumer names a
;;; colour or font directly.

(define-module (dots theme base)
  #:use-module (guix records)
  #:use-module (ice-9 format)
  #:export (theme theme?
            theme-name theme-dark?
            theme-colors theme-color
            theme-fonts theme-shape
            theme-emacs theme-gtk theme-icons theme-cursor
            fonts fonts?
            fonts-mono fonts-sans fonts-size
            shape shape?
            shape-gaps shape-radius shape-border shape-opacity
            hex->rgba alpha-hex))

(define-record-type* <fonts> fonts make-fonts
  fonts?
  (mono fonts-mono (default "Maple Mono NF"))
  (sans fonts-sans (default "DejaVu Sans"))
  (size fonts-size (default 11)))

(define-record-type* <shape> shape make-shape
  shape?
  (gaps    shape-gaps    (default 22))
  (radius  shape-radius  (default 8))
  (border  shape-border  (default 2))
  (opacity shape-opacity (default 0.4)))

;;; The colours alist must define every role below, so any consumer can
;;; rely on them: surfaces (bg bg-dim bg-alt bg-active bg-inactive), text
;;; (fg fg-dim fg-alt), chrome (border cursor selection accent accent-fg),
;;; ANSI normal (black red green yellow blue magenta cyan white) and ANSI
;;; bright (bright-black .. bright-white).

(define-record-type* <theme> theme make-theme
  theme?
  (name   theme-name)
  (dark?  theme-dark?  (default #t))
  (colors theme-colors)
  (fonts  theme-fonts  (default (fonts)))
  (shape  theme-shape  (default (shape)))
  (emacs  theme-emacs  (default "modus-vivendi"))
  (gtk    theme-gtk    (default "Adwaita-dark"))
  (icons  theme-icons  (default "Adwaita"))
  (cursor theme-cursor (default "Adwaita")))

(define (theme-color theme role)
  "Return the hex string for ROLE in THEME.  Raise if ROLE is undefined,
so a typo or an incomplete palette fails loudly at build time."
  (or (assq-ref (theme-colors theme) role)
      (error "unknown theme colour" (theme-name theme) role)))

(define (hex->rgba hex alpha)
  "Convert HEX (a \"#rrggbb\" string) to a CSS rgba() string with opacity
ALPHA in [0, 1]."
  (define (channel start)
    (string->number (substring hex start (+ start 2)) 16))
  (format #f "rgba(~a, ~a, ~a, ~a)"
          (channel 1) (channel 3) (channel 5) alpha))

(define (alpha-hex alpha)
  "Convert opacity ALPHA in [0, 1] to a two-digit hex byte, for #rrggbbaa."
  (let ((s (number->string (inexact->exact (round (* alpha 255))) 16)))
    (if (= (string-length s) 1) (string-append "0" s) s)))
