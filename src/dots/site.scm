;;; The machines a person declares, and which of them this is. Every function
;;; takes the list, so an entry file names the person's module and nothing else.

(define-module (dots site)
  #:use-module (srfi srfi-1)
  #:use-module (gnu machine)
  #:use-module (dots machine)
  #:use-module (dots user)
  #:export (current-hostname machine-named current-machine current-user
            current-operating-system current-home deploy-targets))

(define (current-hostname)
  (or (getenv "DOTS_HOSTNAME") (gethostname)))

(define (machine-named machines name)
  (find (lambda (m) (string=? (machine-host-name m) name)) machines))

(define (current-machine machines)
  (or (machine-named machines (current-hostname))
      (error "no machine defined for host" (current-hostname))))

(define (current-user machines)
  (let ((want (or (getenv "DOTS_USER") (getenv "USER"))))
    (or (find (lambda (u) (string=? (user-name u) want))
              (machine-users (current-machine machines)))
        (error "no user" want "on" (current-hostname)))))

(define (current-operating-system machines)
  (machine->operating-system (current-machine machines)))

(define (current-home machines)
  (machine-home (current-machine machines) (current-user machines)))

(define (deploy-targets machines)
  (map (lambda (m)
         (machine
          (operating-system (machine->operating-system m))
          (environment managed-host-environment-type)
          (configuration (machine-ssh m))))
       (filter machine-address machines)))
