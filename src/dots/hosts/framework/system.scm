;;; Framework system overrides — consumed by (system-setting 'key).
;;; Loaded automatically by (dots settings) via (gethostname); -L src
;;; is enough on the reconfigure command line.

(define-module (dots hosts framework system)
  #:use-module (gnu)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dbus)
  #:use-module (gnu services ssh)
  #:use-module (gnu services virtualization)
  #:use-module (gnu system pam)
  #:use-module (guix gexp)
  #:use-module (dots system users)
  #:use-module (dots system services lgeh)
  #:use-module (dots lab network)
  #:use-module (dots lab services lan-forward)
  #:export (override-hostname
            override-users
            override-groups
            override-file-systems
            override-swap-devices
            override-extra-services))

(define override-hostname "framework")

(define override-users (list %bfh))

;; bfh's supplementary-groups reference libvirt and i2c; declare both here
;; (i2c mirrors the system default, kept because overrides replace it).
(define override-groups
  (list (user-group (name "libvirt") (system? #t))
        (user-group (name "i2c") (system? #t))))

(define override-file-systems
  (list (file-system
          (device (file-system-label "root"))
          (mount-point "/")
          (type "ext4"))
        (file-system
          (device (uuid "DD8A-2ACD" 'fat))
          (mount-point "/boot/efi")
          (type "vfat"))))

(define override-swap-devices
  (list (swap-space
         (target (uuid "008ed7c6-e6cb-4106-99b4-5eee8e5a7eec")))))

;; The eww-broker runs under the persistent Guix Home shepherd, which lives in a
;; long-dead login session (elogind reports it sessionless). NetworkManager's
;; wifi.scan polkit action is allow_any=auth_admin, so a sessionless caller is
;; denied ("not authorized") and the wifi list collapses to the connected AP.
;; Grant wifi.scan to the netdev group (bfh is a member) regardless of session.
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

(define override-extra-services
  (append
   (lgeh-services)
   (lab-network-services)
   (lan-forwarders
    '((jellyfin-forward 8096 "10.20.0.11" 8096)))
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
         ;; daemon sandbox (rg34xxsp images). The manual dynamic-qemu handler
         ;; could not run in the chroot.
         (service qemu-binfmt-service-type
                  (qemu-binfmt-configuration
                   (platforms (lookup-qemu-platforms "aarch64"))))
         (service openssh-service-type
                  (openssh-configuration
                   (port-number 2226)
                   (password-authentication? #t)
                   (permit-root-login #f)))
         )))
