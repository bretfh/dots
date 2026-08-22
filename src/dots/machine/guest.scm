(define-module (dots machine guest)
  #:use-module (oop goops)
  #:use-module (gnu)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services networking)
  #:use-module (gnu services ssh)
  #:use-module (guix gexp)
  #:use-module (dots machine base)
  #:use-module (dots user)
  #:use-module (dots user bfh)
  #:export (<guest>
            guest-bootstrap?
            %builder-substitute-url))

(define %builder-substitute-url "http://10.20.0.10:8080")

(define-class <guest> (<machine>))


;; The builder cannot pull substitutes from itself.
(define-generic guest-bootstrap?)
(define-method (guest-bootstrap? (m <guest>)) #f)

(define-method (machine-users (m <guest>)) (list bfh))

(define-method (machine-kernel-arguments (m <guest>)) '("console=ttyS0,115200"))

(define-method (machine-bootloader (m <guest>))
  (bootloader-configuration
   (bootloader grub-bootloader)
   (targets '("/dev/vda"))
   (terminal-outputs '(console serial_0))))

(define-method (machine-file-systems (m <guest>))
  ;; `guix system image -t qcow2' labels the root partition "Guix_image"
  ;; regardless of what is declared, so `guix deploy' can verify it.
  (list (file-system
          (mount-point "/")
          (device (file-system-label "Guix_image"))
          (type "ext4"))))

(define (guest-substitutes m)
  (lambda (config)
    (guix-configuration
     (inherit config)
     (substitute-urls
      (if (guest-bootstrap? m)
          (cons "https://substitutes.nonguix.org" %default-substitute-urls)
          (cons* %builder-substitute-url
                 "https://substitutes.nonguix.org"
                 %default-substitute-urls)))
     (authorized-keys
      (append (list (local-file "../../../keys/builder.pub"))
              (cons (local-file "../../../keys/nonguix.pub")
                    %default-authorized-guix-keys))))))

(define-method (machine-services (m <guest>))
  (append
   (list (service dhcpcd-service-type)
         (service openssh-service-type
                  (openssh-configuration
                   (port-number 2226)
                   (password-authentication? #f)
                   (permit-root-login 'prohibit-password)
                   (authorized-keys
                    `(("bfh"  ,(local-file "../../../authorized-keys/bfh.pub"))
                      ("root" ,(local-file "../../../authorized-keys/bfh.pub")))))))
   (modify-services (next-method)
     (guix-service-type config => ((guest-substitutes m) config)))))
