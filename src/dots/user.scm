(define-module (dots user)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (gnu system shadow)
  #:use-module (gnu home)
  #:export (<user>
            user-name
            user-primary-group
            user-groups
            user-comment
            user-shell
            user-home-directory
            user-packages
            user-services
            user-desktop
            user->account
            user->home))

(define-class <user> ()
  (name #:init-keyword #:name #:getter user-name))

(define-generic user-primary-group)
(define-generic user-groups)
(define-generic user-comment)
(define-generic user-shell)
(define-generic user-home-directory)
(define-generic user-packages)
(define-generic user-services)
(define-generic user-desktop)

(define-method (user-primary-group  (u <user>)) "users")
(define-method (user-groups         (u <user>)) '())
(define-method (user-comment        (u <user>)) "")
(define-method (user-shell          (u <user>)) #f)
(define-method (user-home-directory (u <user>))
  (string-append "/home/" (user-name u)))
(define-method (user-packages       (u <user>) machine) '())
(define-method (user-services       (u <user>) machine) '())
(define-method (user-desktop        (u <user>)) #f)

(define (user->account u)
  (let ((acct (user-account
               (name (user-name u))
               (comment (user-comment u))
               (group (user-primary-group u))
               (home-directory (user-home-directory u))
               (supplementary-groups (user-groups u)))))
    (if (user-shell u)
        (user-account (inherit acct) (shell (user-shell u)))
        acct)))

(define* (user->home u #:optional machine)
  (home-environment
   (packages (user-packages u machine))
   (services (user-services u machine))))
