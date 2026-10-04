(define-module (dots input)
  #:use-module (guix records)
  #:use-module (srfi srfi-1)
  #:export (keyboard keyboard?
            keyboard-layout keyboard-options keyboard-options-string
            %default-keyboard))

(define-record-type* <keyboard> keyboard make-keyboard
  keyboard?
  (layout  keyboard-layout  (default "us"))
  (options keyboard-options (default '())))

(define (keyboard-options-string k)
  (string-join (keyboard-options k) ","))

(define %default-keyboard (keyboard))
