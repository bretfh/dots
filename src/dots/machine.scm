(define-module (dots machine)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (gnu)
  #:use-module (gnu system nss)
  #:use-module (gnu home)
  #:use-module (gnu packages linux)
  #:use-module (gnu system linux-initrd)
  #:use-module ((dots input) #:prefix in:)
  #:use-module (dots user)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services desktop)
  #:use-module (gnu services networking)
  #:use-module (gnu packages)
  #:use-module (guix gexp)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (dots packages stumpwm)
  #:use-module (dots packages pine-session)
  #:use-module (gnu services ssh)
  #:export (<machine> <workstation> <guest> with-nonguix-substitutes
            %builder-substitute-url
            machine-host-name
            machine-locale machine-timezone machine-keyboard
            machine-kernel machine-initrd machine-firmware machine-bootloader
            machine-file-systems machine-swap-devices
            machine-users machine-groups
            machine-packages machine-services
            machine-name-service-switch
            machine-kernel-arguments
            machine-address
            machine-keyboard-layout
            machine->operating-system
            machine-home))

(define-class <machine> ()
  (address #:init-keyword #:address #:init-value #f #:getter machine-address))

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
(define-generic machine-name-service-switch)
(define-generic machine-kernel-arguments)
(define-generic machine-groups)

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
(define-method (machine-name-service-switch (m <machine>)) %mdns-host-lookup-nss)
(define-method (machine-kernel-arguments    (m <machine>)) '())

;;; A user states the groups it needs to exist. Only the ones guix does not
;;; already provide are declared here; a machine adds any its own services
;;; require.
(define-method (machine-groups (m <machine>))
  (let ((base (map user-group-name %base-groups)))
    (filter-map (lambda (n)
                  (and (not (member n base))
                       (user-group (name n) (system? #t))))
                (delete-duplicates
                 (append-map (lambda (u) (user-groups u m)) (machine-users m))))))

(define (machine-keyboard-layout m)
  (let ((k (machine-keyboard m)))
    (keyboard-layout (in:keyboard-layout k) #:options (in:keyboard-options k))))

(define (machine-home m user) (user->home user m))

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
   (users           (append (map (lambda (u) (user->account u m)) (machine-users m))
                            %base-user-accounts))
   (groups          (delete-duplicates
                     (append (machine-groups m) %base-groups)
                     (lambda (a b) (string=? (user-group-name a)
                                             (user-group-name b)))))
   (packages        (append (machine-packages m) %base-packages))
   (services        (machine-services m))
   (name-service-switch (machine-name-service-switch m))))


;;; Archetypes. They live here, beside <machine>, because a class whose
;;; parent is in another module does not survive guix's config loader when two
;;; siblings are imported together.

(define-class <workstation> (<machine>))

(define-method (machine-kernel   (m <workstation>)) linux)
(define-method (machine-initrd   (m <workstation>)) microcode-initrd)
(define-method (machine-firmware (m <workstation>))
  (list iwlwifi-firmware sof-firmware linux-firmware))

(define-method (machine-bootloader (m <workstation>))
  (bootloader-configuration
   (bootloader grub-efi-bootloader)
   (targets '("/boot/efi"))
   (keyboard-layout (machine-keyboard-layout m))))

(define-method (machine-packages (m <workstation>))
  (append (list pine-session)
          (map specification->package
               '("openssh"
                 "sway" "niri" "swaylock" "swayidle" "wlgreet"
                 "xorg-server-xwayland" "xwayland-satellite" "alacritty"
                 "pipewire" "wireplumber" "pavucontrol"
                 "wofi" "wl-clipboard" "mako"
                 "network-manager" "network-manager-applet"
                 "brightnessctl" "ddcutil" "git"))
          %stumpwm-packages))

(define (with-nonguix-substitutes services)
  (modify-services services
    (guix-service-type config =>
      (guix-configuration
       (inherit config)
       (substitute-urls
        (cons "https://substitutes.nonguix.org" %default-substitute-urls))
       (authorized-keys
        (cons (local-file "../../keys/nonguix.pub")
              %default-authorized-guix-keys))))))

(define-method (machine-services (m <workstation>))
  (with-nonguix-substitutes
   (modify-services (cons (service gnome-desktop-service-type)
                            %desktop-services)
       (network-manager-service-type config =>
         (network-manager-configuration
          (inherit config)
          (dns "none"))))))


(define %builder-substitute-url "http://10.20.0.10:8080")

(define-class <guest> (<machine>))


;; The builder cannot pull substitutes from itself.
(define-generic guest-bootstrap?)
(define-method (guest-bootstrap? (m <guest>)) #f)

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
      (append (list (local-file "../../keys/builder.pub"))
              (cons (local-file "../../keys/nonguix.pub")
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
                    `(("bfh"  ,(local-file "../../authorized-keys/bfh.pub"))
                      ("root" ,(local-file "../../authorized-keys/bfh.pub")))))))
   (modify-services (next-method)
     (guix-service-type config => ((guest-substitutes m) config)))))
