(define-module (dots home services zsh)
  #:use-module (oop goops)
  #:use-module (gnu services)
  #:use-module (gnu home services shells)
  #:use-module (guix gexp)
  #:use-module (dots shell)
  #:export (<zsh> zsh))

(define-class <zsh> (<shell>))
(define zsh (make <zsh> #:name 'zsh))

(define-method (shell-services (s <zsh>) env)
  (list (service home-zsh-service-type
                 (home-zsh-configuration
                  (package (shell-package s))
                  ;; .zshenv is read for every invocation, login or not,
                  ;; interactive or not -- the one place PATH belongs.
                  (zshenv
                   (let ((line (path-export-line (environment-paths env))))
                     (if (string-null? line)
                         '()
                         (list (plain-file "path" line)))))
                  (zshrc (list (plain-file "aliases"
                                           (alias-lines (environment-aliases env)))))
                  (zprofile
                   (if (string-null? (environment-login env))
                       '()
                       (list (plain-file "login" (environment-login env)))))))))
