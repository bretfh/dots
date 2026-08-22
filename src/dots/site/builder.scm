;;; builder -- guest; signed substitute server (guix publish) on :8080

(define-module (dots site builder)
  #:use-module (oop goops)
  #:use-module (gnu)
  #:use-module (gnu services)
  #:use-module (gnu services guix)
  #:use-module (dots machine)
  #:use-module (dots site users)
  #:export (<builder>))

(define-class <builder> (<guest>))

(define-method (machine-users (m <builder>)) (list bfh))

(define-method (machine-host-name (m <builder>)) "builder")

(define-method (machine-address (m <builder>)) "10.20.0.10")

(define-method (guest-bootstrap? (m <builder>)) #t)

(define-method (machine-services (m <builder>))
  (cons (service guix-publish-service-type
                 (guix-publish-configuration
                  (host "0.0.0.0")
                  (port 8080)
                  (cache "/var/cache/publish")
                  (compression '(("zstd" 3)))))
        (next-method)))

;;; The media VM: Jellyfin in a container, host music share mounted at /srv/media.
