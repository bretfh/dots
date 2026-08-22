;;; framework -- workstation; libvirt host, lab services, no DDC/CI monitor

(define-module (dots site framework)
  #:use-module (oop goops)
  #:use-module (gnu)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dbus)
  #:use-module (gnu services ssh)
  #:use-module (gnu services virtualization)
  #:use-module (gnu system pam)
  #:use-module (guix gexp)
  #:use-module (dots machine)
  #:use-module (dots user)
  #:use-module (dots site users)
  #:use-module (dots system services lgeh)
  #:use-module (dots lab network)
  #:use-module (dots lab services lan-forward)
  #:use-module (dots packages opentofu)
  #:use-module (dots packages litestream)
  #:export (<framework>))

(define-class <framework> (<workstation>))

(define-method (machine-users (m <framework>)) (list bfh))

(define-method (machine-host-name (m <framework>)) "framework")

;; bfh drives libvirt here without sudo.
(define-method (user-groups (u <bfh>) (m <framework>))
  (cons "libvirt" (next-method)))

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
(define-method (user-packages (u <bfh>) (m <framework>))
  (append
   (next-method)
   (list (specification->package "llama-cpp")
        opentofu
        litestream
        (specification->package "virt-manager")
        (specification->package "virt-viewer")
        (specification->package "libvirt")
        (specification->package "mkcert")
        (specification->package "wezterm")
        (specification->package "github-cli")
         (specification->package "awscli"))))

;; NetworkManager's wifi.scan polkit action is allow_any=auth_admin, so a
;; sessionless caller -- anything under the persistent Guix Home shepherd, which
;; elogind reports as having no session -- is denied and the wifi list collapses
;; to the connected AP. Grant wifi.scan to netdev regardless of session.
;; NetworkManager's wifi.scan polkit action is allow_any=auth_admin, so a
;; sessionless caller -- anything under the persistent Guix Home shepherd,
;; which elogind reports as having no session -- is denied and the wifi list
;; collapses to the connected AP. Grant wifi.scan to netdev regardless.

(define nm-wifi-scan-polkit
  (computed-file
   "nm-wifi-scan-polkit"
   (with-imported-modules '((guix build utils))
     #~(begin
         (use-modules (guix build utils))
         (let ((dir (string-append #$output "/share/polkit-1/rules.d")))
           (mkdir-p dir)
           (call-with-output-file (string-append dir "/10-nm-wifi-scan.rules")
             (lambda (port)
               (display "polkit.addRule(function(action, subject) {
    if (action.id == \"org.freedesktop.NetworkManager.wifi.scan\" &&
        subject.isInGroup(\"netdev\")) {
        return polkit.Result.YES;
    }
});
" port))))))))

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
