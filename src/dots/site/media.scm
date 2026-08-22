;;; media -- guest; Jellyfin in a container, host music share at /srv/media

(define-module (dots site media)
  #:use-module (oop goops)
  #:use-module (gnu)
  #:use-module (gnu services)
  #:use-module (gnu services dbus)
  #:use-module (gnu services desktop)
  #:use-module (gnu services docker)
  #:use-module (gnu services containers)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (dots machine)
  #:use-module (dots site users)
  #:export (<media>))

(define-class <media> (<guest>))

(define-method (machine-users (m <media>)) (list bfh))

(define-method (machine-host-name (m <media>)) "media")

(define-method (machine-address (m <media>)) "10.20.0.11")
;; Declared as a shepherd one-shot rather than a file-system because
;; `guix deploy' validates declared file-systems against real block devices
;; and "music" is a virtio tag, not a /dev path.

(define %mount-music-9p
  (shepherd-service
   (provision '(mount-music))
   (requirement '(networking))
   (one-shot? #t)
   (start #~(lambda _
              (mkdir-p "/srv/media")
              (system* "/run/current-system/profile/sbin/mount"
                       "-t" "9p" "-o"
                       "trans=virtio,version=9p2000.L,ro"
                       "music" "/srv/media")
              #t))
   (stop #~(const #f))))

(define-method (machine-services (m <media>))
  (append
   (list (service dbus-root-service-type)
         (service elogind-service-type)
         (service polkit-service-type)
         (service containerd-service-type)
         (service docker-service-type)
         (simple-service 'mount-music shepherd-root-service-type
                         (list %mount-music-9p))
         ;; libvirt's host DNS forwarder times out talking to the router;
         ;; dhcpcd respects resolv.conf.head, so this survives lease renewals.
         (simple-service 'override-resolv-conf-head etc-service-type
                         `(("resolv.conf.head"
                            ,(plain-file "resolv.conf.head"
                                         "nameserver 1.1.1.1\nnameserver 8.8.8.8\n"))))
         (service oci-service-type
                  (oci-configuration
                   (containers
                    (list
                     (oci-container-configuration
                      (image "jellyfin/jellyfin:latest")
                      (provision "jellyfin")
                      (auto-start? #t)
                      (respawn? #t)
                      (ports '(("8096" . "8096")))
                      (volumes '(("/srv/jellyfin/config" . "/config")
                                 ("/srv/jellyfin/cache"  . "/cache")
                                 ("/srv/media"           . "/media:ro")))))))))
   (next-method)))
