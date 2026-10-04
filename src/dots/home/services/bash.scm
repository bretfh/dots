(define-module (dots home services bash)
  #:use-module (oop goops)
  #:use-module (gnu services)
  #:use-module (gnu home services shells)
  #:use-module (guix gexp)
  #:use-module (dots shell)
  #:export (<bash> bash))

(define-class <bash> (<shell>))
(define bash (make <bash> #:name 'bash))

(define-method (shell-services (s <bash>) env)
  (list (service home-bash-service-type
                 (home-bash-configuration
                  (package (shell-package s))
                  (aliases (environment-aliases env))
                  (bashrc
                   (let ((line (path-export-line (environment-paths env))))
                     (if (string-null? line)
                         '()
                         (list (plain-file "path" line)))))
                  (bash-profile
                   (if (string-null? (environment-login env))
                       '()
                       (list (plain-file "login" (environment-login env)))))))))
