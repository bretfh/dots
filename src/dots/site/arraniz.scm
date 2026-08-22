;;; arraniz -- workstation; drives an external monitor over DDC/CI

(define-module (dots site arraniz)
  #:use-module (oop goops)
  #:use-module (gnu)
  #:use-module (gnu packages)
  #:use-module (dots machine)
  #:use-module (dots user)
  #:use-module (dots site users)
  #:export (<arraniz>))

(define-class <arraniz> (<workstation>))

(define-method (machine-users (m <arraniz>)) (list bfh))

(define-method (machine-host-name (m <arraniz>)) "arraniz")

(define-method (machine-file-systems (m <arraniz>))
  (list (file-system
          (device (file-system-label "root"))
          (mount-point "/")
          (type "ext4"))
        (file-system
          (device (uuid "D140-4BF5" 'fat))
          (mount-point "/boot/efi")
          (type "vfat"))))

;; ddcutil's udev rule grants the i2c group /dev/i2c-* for external-monitor
;; brightness. framework has no DDC/CI monitor and omits both.
(define-method (user-groups (u <bfh>) (m <arraniz>))
  (cons "i2c" (next-method)))

(define-method (machine-services (m <arraniz>))
  (cons (udev-rules-service 'ddcutil (specification->package "ddcutil"))
        (next-method)))

(define-method (machine-swap-devices (m <arraniz>))
  (list (swap-space
         (target (uuid "a0bca027-0738-4287-933b-42f5960a25ed")))))

;;; The builder VM: signed substitute server (guix publish) on :8080.

;;; First boot signing key:

;;;   ssh -p 2226 root@10.20.0.10 'guix archive --generate-key'

;;;   ssh -p 2226 root@10.20.0.10 'cat /etc/guix/signing-key.pub' > keys/builder.pub
