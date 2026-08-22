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

;;; Everything a user is asked takes the machine, so one user can differ
;;; across the machines that carry it -- dispatch on (user, machine).
(define-method (user-primary-group  (u <user>) m) "users")
(define-method (user-groups         (u <user>) m) '())
(define-method (user-comment        (u <user>) m) "")
(define-method (user-shell          (u <user>) m) #f)
(define-method (user-home-directory (u <user>) m)
  (string-append "/home/" (user-name u)))
(define-method (user-packages       (u <user>) m) '())
(define-method (user-services       (u <user>) m) '())
(define-method (user-desktop        (u <user>) m) #f)

(define (user->account u m)
  (let ((acct (user-account
               (name (user-name u))
               (comment (user-comment u m))
               (group (user-primary-group u m))
               (home-directory (user-home-directory u m))
               (supplementary-groups (user-groups u m)))))
    (if (user-shell u m)
        (user-account (inherit acct) (shell (user-shell u m)))
        acct)))

(define (user->home u m)
  (home-environment
   (packages (user-packages u m))
   (services (user-services u m))))
