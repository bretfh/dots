;;; INI from data. Input is a list of sections; each section is
;;; (NAME (KEY . VALUE) ...). NAME #f is the headerless leading section.
;;; Values are written bare (key=value); strings pass through verbatim,
;;; booleans become 1/0, numbers/symbols stringify.

(define-module (dots config ini)
  #:use-module (ice-9 match)
  #:export (ini))

(define (name->string k) (if (symbol? k) (symbol->string k) k))

(define (value v)
  (cond ((string? v)  v)
        ((boolean? v) (if v "1" "0"))
        ((number? v)  (number->string v))
        ((symbol? v)  (symbol->string v))
        (else (object->string v))))

(define (section->string s)
  (match s
    ((name . pairs)
     (string-append
      (if name (string-append "[" (name->string name) "]\n") "")
      (string-join
       (map (lambda (kv)
              (string-append (name->string (car kv)) "=" (value (cdr kv))))
            pairs)
       "\n")))))

(define (ini sections)
  "Serialize SECTIONS -- a list of (NAME (KEY . VALUE) ...) -- to INI."
  (string-join (map section->string sections) "\n\n"))
