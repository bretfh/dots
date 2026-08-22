(define-module (dots machine base)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (gnu)
  #:use-module (gnu system nss)
  #:use-module (gnu home)
  #:use-module (gnu packages linux)
  #:use-module (gnu system linux-initrd)
  #:use-module ((dots input) #:prefix in:)
  #:use-module (dots user)
  #:export (<machine>
            machine-host-name
            machine-locale machine-timezone machine-keyboard
            machine-kernel machine-initrd machine-firmware machine-bootloader
            machine-file-systems machine-swap-devices
            machine-users machine-groups
            machine-packages machine-services
            machine-home-packages
            machine-name-service-switch
            machine-kernel-arguments
            machine-address
            machine-keyboard-layout
            machine->operating-system
            machine-home))

(define-class <machine> ())

(define-generic machine-host-name)

(define-generic machine-locale)
(define-generic machine-timezone)
(define-generic machine-keyboard)
(define-generic machine-kernel)
(define-generic machine-initrd)
(define-generic machine-firmware)
(define-generic machine-bootloader)
(define-generic machine-file-systems)
(define-generic machine-swap-devices)
(define-generic machine-users)
(define-generic machine-packages)
(define-generic machine-services)
(define-generic machine-home-packages)
(define-generic machine-name-service-switch)
(define-generic machine-kernel-arguments)
(define-generic machine-groups)
(define-generic machine-address)

(define-method (machine-locale        (m <machine>)) "en_US.utf8")
(define-method (machine-timezone      (m <machine>)) "America/New_York")
(define-method (machine-keyboard      (m <machine>)) in:%default-keyboard)
(define-method (machine-kernel        (m <machine>)) linux-libre)
(define-method (machine-initrd        (m <machine>)) base-initrd)
(define-method (machine-firmware      (m <machine>)) %base-firmware)
(define-method (machine-file-systems  (m <machine>)) '())
(define-method (machine-swap-devices  (m <machine>)) '())
(define-method (machine-users         (m <machine>)) '())
(define-method (machine-packages      (m <machine>)) '())
(define-method (machine-services      (m <machine>)) %base-services)
(define-method (machine-home-packages (m <machine>)) '())
(define-method (machine-name-service-switch (m <machine>)) %mdns-host-lookup-nss)
(define-method (machine-kernel-arguments    (m <machine>)) '())
;; Non-#f means `guix deploy' can reach it; that is what makes a machine a guest.
(define-method (machine-address             (m <machine>)) #f)

;;; A user states the groups it needs to exist; a machine carrying that user
;;; declares them. A machine adds groups its own services require.
(define-method (machine-groups (m <machine>))
  (map (lambda (n) (user-group (name n) (system? #t)))
       (delete-duplicates (append-map user-groups (machine-users m)))))

(define (machine-keyboard-layout m)
  (let ((k (machine-keyboard m)))
    (keyboard-layout (in:keyboard-layout k) #:options (in:keyboard-options k))))

(define (machine-home m user)
  (home-environment
   (packages (append (machine-home-packages m) (user-packages user m)))
   (services (user-services user m))))

(define (machine->operating-system m)
  (operating-system
   (host-name       (machine-host-name m))
   (timezone        (machine-timezone m))
   (locale          (machine-locale m))
   (keyboard-layout (machine-keyboard-layout m))
   (kernel          (machine-kernel m))
   (kernel-arguments (append (machine-kernel-arguments m) %default-kernel-arguments))
   (initrd          (machine-initrd m))
   (firmware        (machine-firmware m))
   (bootloader      (machine-bootloader m))
   (file-systems    (append (machine-file-systems m) %base-file-systems))
   (swap-devices    (machine-swap-devices m))
   (users           (append (map user->account (machine-users m))
                            %base-user-accounts))
   (groups          (delete-duplicates
                     (append (machine-groups m) %base-groups)
                     (lambda (a b) (string=? (user-group-name a)
                                             (user-group-name b)))))
   (packages        (append (machine-packages m) %base-packages))
   (services        (machine-services m))
   (name-service-switch (machine-name-service-switch m))))
