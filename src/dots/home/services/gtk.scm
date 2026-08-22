(define-module (dots home services gtk)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (ice-9 format)
  #:use-module (dots theme base)
  #:use-module (dots config ini)
  #:use-module (dots core)
  #:use-module (dots desktop)
  #:export (gtk-settings
            gtk3-css
            gtk4-css
            <gtk> gtk))

(define (define-colors pairs)
  "Emit GTK @define-color lines from (TOKEN . COLOUR) pairs."
  (string-join
   (map (lambda (p) (format #f "@define-color ~a ~a;" (car p) (cdr p))) pairs)
   "\n"))

(define (gtk-settings theme)
  "Return settings.ini contents: dark preference, icon/cursor themes, and the
UI font, from THEME."
  (define f (theme-fonts theme))
  (ini
   `((Settings (gtk-application-prefer-dark-theme . 1)
               (gtk-theme-name . ,(theme-gtk theme))
               (gtk-icon-theme-name . ,(theme-icons theme))
               (gtk-cursor-theme-name . ,(theme-cursor theme))
               (gtk-font-name . ,(format #f "~a ~a" (fonts-sans f) (fonts-size f)))))))

(define* (gtk3-css theme #:key (extra '()))
  "Return gtk-3.0/gtk.css: override GTK3's named theme colours from THEME.
EXTRA holds rules contributed by components that need to skin their own
widgets, so this file names no application."
  (define (c role) (theme-color theme role))
  (string-append
   (define-colors
     `((theme_bg_color . ,(c 'bg))
       (theme_base_color . ,(c 'bg-dim))
       (theme_fg_color . ,(c 'fg))
       (theme_text_color . ,(c 'fg))
       (theme_selected_bg_color . ,(c 'accent))
       (theme_selected_fg_color . ,(c 'accent-fg))
       (insensitive_bg_color . ,(c 'bg-dim))
       (insensitive_fg_color . ,(c 'fg-dim))
       (borders . ,(c 'border))
       (warning_color . ,(c 'yellow))
       (error_color . ,(c 'red))
       (success_color . ,(c 'green))))
   "\n"
   (string-join extra "\n")
   "\n"))

(define (gtk4-css theme)
  "Return gtk-4.0/gtk.css: override libadwaita's named colours from THEME, so
GTK4 apps follow the palette within libadwaita's structure."
  (define (c role) (theme-color theme role))
  (define-colors
    `((window_bg_color . ,(c 'bg)) (window_fg_color . ,(c 'fg))
      (view_bg_color . ,(c 'bg-dim)) (view_fg_color . ,(c 'fg))
      (headerbar_bg_color . ,(c 'bg-alt)) (headerbar_fg_color . ,(c 'fg))
      (sidebar_bg_color . ,(c 'bg-dim)) (sidebar_fg_color . ,(c 'fg))
      (card_bg_color . ,(c 'bg-alt)) (card_fg_color . ,(c 'fg))
      (popover_bg_color . ,(c 'bg-alt)) (popover_fg_color . ,(c 'fg))
      (dialog_bg_color . ,(c 'bg-alt)) (dialog_fg_color . ,(c 'fg))
      (accent_bg_color . ,(c 'accent)) (accent_fg_color . ,(c 'accent-fg))
      (accent_color . ,(c 'fg-alt))
      (destructive_bg_color . ,(c 'red))
      (success_color . ,(c 'green))
      (warning_color . ,(c 'yellow))
      (error_color . ,(c 'red)))))

(define-class <gtk> (<toolkit>))
(define gtk (make <gtk> #:name 'gtk))

(define-method (component-config-files (c <gtk>) desktop)
  (let* ((theme    (desktop-theme desktop))
         (settings (gtk-settings theme)))
    `(("gtk-3.0/settings.ini" ,(plain-file "gtk3-settings.ini" settings))
      ("gtk-3.0/gtk.css"
       ,(plain-file "gtk3.css"
                    (gtk3-css theme #:extra (desktop-gtk-css desktop))))
      ("gtk-4.0/settings.ini" ,(plain-file "gtk4-settings.ini" settings))
      ("gtk-4.0/gtk.css" ,(plain-file "gtk4.css" (gtk4-css theme))))))
