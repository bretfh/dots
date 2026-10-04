(deftheme vex "a theme")

(let* (
       (soothing-ivory "#d9d9d9")
       (deep-ember "#ff3300")
       (autumn-orange "#ff6600")
       (harvest-gold "#ffcc00")
       (pumpkin-spice "#ff9966")
       (muted-tangerine "#ffcc99"
       (dark-coffee "#270d06")
       (burnt-sienna "#330000")
       (copper-red "#663300")
       )

  (custom-theme-set-faces
   'vex
   ;; Basic coloring
   `(default ((t (:foreground ,soothing-ivory :background ,dark-coffee))))
   `(cursor ((t (:background ,autumn-orange))))
   `(region ((t (:background ,muted-tangerine))))
   `(mode-line ((t (:foreground ,soothing-ivory :background ,burnt-sienna))))
   `(mode-line-inactive ((t (:foreground ,soothing-ivory :background ,copper-red))))

   ;; Syntax highlighting
   `(highlight ((t (:background ,deep-ember))))
   `(minibuffer-prompt ((t (:foreground ,deep-ember))))

   ;; Font lock for syntax coloring
   `(font-lock-builtin-face ((t (:foreground ,autumn-orange))))
   `(font-lock-constant-face ((t (:foreground ,harvest-gold))))
   `(font-lock-comment-face ((t (:foreground ,muted-tangerine))))
   `(font-lock-function-name-face ((t (:foreground ,pumpkin-spice))))
   `(font-lock-keyword-face ((t (:foreground ,deep-ember))))
   `(font-lock-string-face ((t (:foreground ,pumpkin-spice))))
   `(font-lock-type-face ((t (:foreground ,harvest-gold))))
   `(font-lock-variable-name-face ((t (:foreground ,muted-tangerine))))
   `(font-lock-warning-face ((t (:foreground ,deep-ember :bold t))))
   
   )
  )

(provide-theme 'vex)
