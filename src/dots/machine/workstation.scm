(define-module (dots machine workstation)
  #:use-module (oop goops)
  #:use-module (gnu)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services desktop)
  #:use-module (gnu services networking)
  #:use-module (gnu packages)
  #:use-module (guix gexp)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (dots machine base)
  #:use-module (dots user)
  #:use-module (dots user bfh)
  #:use-module (dots packages stumpwm)
  #:use-module (dots packages pine-session)
  #:export (<workstation> with-nonguix-substitutes))

(define-class <workstation> (<machine>))

(define-method (machine-users    (m <workstation>)) (list bfh))
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
        (cons (local-file "../../../keys/nonguix.pub")
              %default-authorized-guix-keys))))))

(define-method (machine-services (m <workstation>))
  (with-nonguix-substitutes
   (modify-services (cons (service gnome-desktop-service-type)
                            %desktop-services)
       (network-manager-service-type config =>
         (network-manager-configuration
          (inherit config)
          (dns "none"))))))
