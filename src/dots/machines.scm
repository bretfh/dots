(define-module (dots machines)
  #:use-module (oop goops)
  #:use-module (gnu)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dbus)
  #:use-module (gnu services desktop)
  #:use-module (gnu services docker)
  #:use-module (gnu services containers)
  #:use-module (gnu services guix)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services ssh)
  #:use-module (gnu services virtualization)
  #:use-module (gnu system pam)
  #:use-module (guix gexp)
  #:use-module (dots machine base)
  #:use-module (dots machine workstation)
  #:use-module (dots machine guest)
  #:use-module (dots system services lgeh)
  #:use-module (dots lab network)
  #:use-module (dots lab services lan-forward)
  #:export (<framework> <arraniz> <builder> <media>))

;;; framework -- workstation; libvirt host, lab services, no DDC/CI monitor

(define-class <framework> (<workstation>))
(define-method (machine-host-name (m <framework>)) "framework")
(define-method (machine-groups (m <framework>))
  (cons (user-group (name "libvirt") (system? #t)) (next-method)))
(define-method (machine-file-systems (m <framework>))
  (list (file-system
          (device (file-system-label "root"))
          (mount-point "/")
          (type "ext4"))
        (file-system
          (device (uuid "DD8A-2ACD" 'fat))
          (mount-point "/boot/efi")
          (type "vfat"))))
(define-method (machine-swap-devices (m <framework>))
  (list (swap-space
         (target (uuid "008ed7c6-e6cb-4106-99b4-5eee8e5a7eec")))))

;; framework is the LLM host, so the llama-cpp server and its tooling live here.
(define-method (machine-home-packages (m <framework>))
  (list (specification->package "llama-cpp")
        opentofu
        litestream
        (specification->package "virt-manager")
        (specification->package "virt-viewer")
        (specification->package "libvirt")
        (specification->package "mkcert")
        (specification->package "wezterm")
        (specification->package "github-cli")
        (specification->package "awscli")))

;; NetworkManager's wifi.scan polkit action is allow_any=auth_admin, so a
;; sessionless caller -- anything under the persistent Guix Home shepherd, which
;; elogind reports as having no session -- is denied and the wifi list collapses
;; to the connected AP. Grant wifi.scan to netdev regardless of session.
(define-method (machine-services (m <framework>))
  (append
   (lgeh-services)
   (lab-network-services)
   (lan-forwarders '((jellyfin-forward 8096 "10.20.0.11" 8096)))
   (list (simple-service 'nm-wifi-scan-polkit polkit-service-type
                         (list nm-wifi-scan-polkit))
         (simple-service 'gtklock-pam pam-root-service-type
                         (list (unix-pam-service "gtklock")))
         (simple-service 'static-resolv-conf etc-service-type
                         (list (list "resolv.conf"
                                     (plain-file "resolv.conf"
                                                 "nameserver 1.1.1.1\nnameserver 9.9.9.9\nnameserver 192.168.1.1\n"))))
         (service libvirt-service-type
                  (libvirt-configuration
                   (unix-sock-group "libvirt")))
         (service virtlog-service-type)
         ;; Static-qemu binfmt so guix can build aarch64 derivations inside the
         ;; daemon sandbox; the dynamic handler cannot run in the chroot.
         (service qemu-binfmt-service-type
                  (qemu-binfmt-configuration
                   (platforms (lookup-qemu-platforms "aarch64"))))
         (service openssh-service-type
                  (openssh-configuration
                   (port-number 2226)
                   (password-authentication? #t)
                   (permit-root-login #f))))
   (next-method)))


;;; arraniz -- workstation; drives an external monitor over DDC/CI

(define-class <arraniz> (<workstation>))
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
;; brightness. framework has no DDC/CI monitor and deliberately omits it.
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


;;; builder -- guest; signed substitute server (guix publish) on :8080

(define-class <builder> (<guest>))
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


;;; media -- guest; Jellyfin in a container, host music share at /srv/media

(define-class <media> (<guest>))
(define-method (machine-host-name (m <media>)) "media")
(define-method (machine-address (m <media>)) "10.20.0.11")
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
