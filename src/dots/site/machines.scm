(define-module (dots site machines)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (gnu machine)
  #:use-module (gnu machine ssh)
  #:use-module (dots machine)
  #:use-module (dots site framework)
  #:use-module (dots site arraniz)
  #:use-module (dots site builder)
  #:use-module (dots site media)
  #:use-module (dots user)
  #:use-module (dots site users)
  #:export (machines guests
            current-hostname machine-named current-machine current-user
            current-operating-system current-home
            deploy-targets))

;;; Every machine this configuration manages. A guest carries the address
;;; `guix deploy' reaches it on; a workstation has none.
(define (machines)
  (list (make <framework>)
        (make <arraniz>)
        (make <builder> #:address "10.20.0.10")
        (make <media>   #:address "10.20.0.11")))

(define (guests) (filter machine-address (machines)))

(define (current-hostname)
  (or (getenv "DOTS_HOSTNAME") (gethostname)))

(define (machine-named name)
  (find (lambda (m) (string=? (machine-host-name m) name)) (machines)))

(define (current-machine)
  (or (machine-named (current-hostname))
      (error "no machine defined for host" (current-hostname))))

(define (current-user)
  (let ((want (or (getenv "DOTS_USER") (getenv "USER"))))
    (or (find (lambda (u) (string=? (user-name u) want))
              (machine-users (current-machine)))
        (error "no user" want "on" (current-hostname)))))

(define (current-operating-system)
  (machine->operating-system (current-machine)))

(define (current-home)
  (machine-home (current-machine) (current-user)))

(define (deploy-targets)
  (map (lambda (m)
         (machine
          (operating-system (machine->operating-system m))
          (environment managed-host-environment-type)
          (configuration
           (machine-ssh-configuration
            (host-name (machine-address m))
            (system "x86_64-linux")
            (user "root")
            (port 2226)
            (identity (string-append (getenv "HOME") "/.ssh/id_ed25519"))))))
       (guests)))
