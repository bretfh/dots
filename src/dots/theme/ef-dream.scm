(define-module (dots theme ef-dream)
  #:use-module (dots theme base)
  #:export (ef-dream))

(define ef-dream
  (theme
   (name 'ef-dream)
   (emacs "ef-dream")
   (colors
    '((bg          . "#232025") (bg-dim     . "#322f34")
      (bg-alt      . "#3b393e") (bg-active  . "#5b595e")
      (bg-inactive . "#2a272c")
      (fg          . "#efd5c5") (fg-dim     . "#8f8886")
      (fg-alt      . "#b0a0cf")
      (border      . "#635850") (cursor     . "#f3c09a")
      (selection   . "#544a50")
      (accent      . "#675072") (accent-fg  . "#fedeff")
      (black   . "#3b393e") (red     . "#ff6f6f") (green   . "#51b04f")
      (yellow  . "#c0b24f") (blue    . "#57b0ff") (magenta . "#ffaacf")
      (cyan    . "#6fb3c0") (white   . "#8f8886")
      (bright-black   . "#5b595e") (bright-red     . "#ff7a5f")
      (bright-green   . "#7fce5f") (bright-yellow  . "#d09950")
      (bright-blue    . "#80aadf") (bright-magenta . "#d0b0ff")
      (bright-cyan    . "#8fcfd0") (bright-white   . "#efd5c5")))))
