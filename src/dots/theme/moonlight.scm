(define-module (dots theme moonlight)
  #:use-module (dots theme base)
  #:export (moonlight))

(define moonlight
  (theme
   (name 'moonlight)
   (emacs "doom-moonlight")
   (colors
    '((bg          . "#212337") (bg-dim     . "#1f2335")
      (bg-alt      . "#161a2a") (bg-active  . "#444a73")
      (bg-inactive . "#1b1d2b")
      (fg          . "#c8d3f5") (fg-dim     . "#828bb8")
      (fg-alt      . "#b4c2f0")
      (border      . "#444a73") (cursor     . "#c8d3f5")
      (selection   . "#2d3f76")
      (accent      . "#82aaff") (accent-fg  . "#212337")
      (black   . "#161a2a") (red     . "#ff757f") (green   . "#c3e88d")
      (yellow  . "#ffc777") (blue    . "#82aaff") (magenta . "#c099ff")
      (cyan    . "#86e1fc") (white   . "#c8d3f5")
      (bright-black   . "#444a73") (bright-red     . "#ff98a4")
      (bright-green   . "#77e0c6") (bright-yellow  . "#ffcc99")
      (bright-blue    . "#50c4fa") (bright-magenta . "#baacff")
      (bright-cyan    . "#b4f9f8") (bright-white   . "#ffffff")))))
