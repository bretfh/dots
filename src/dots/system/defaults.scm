;;; System defaults. Every knob the single operating-system form reads
;;; has a default-<key> here. Hosts override via (system-overrides) in
;;; per-host/<host>/system.scm.

(define-module (dots system defaults)
  #:use-module (gnu)
  #:use-module (gnu packages)
  #:use-module (gnu services base)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (dots packages stumpwm)
  #:export (default-hostname
            default-locale
            default-timezone
            default-keyboard-layout
            default-kernel
            default-initrd
            default-firmware
            default-bootloader
            default-file-systems
            default-swap-devices
            default-users
            default-groups
            default-extra-packages
            default-extra-services))

(define default-hostname "guix")
(define default-locale   "en_US.utf8")
(define default-timezone "America/New_York")

(define default-keyboard-layout
  (keyboard-layout "us" #:options '("ctrl:swapcaps")))

(define default-kernel   linux)
(define default-initrd   microcode-initrd)
(define default-firmware (list iwlwifi-firmware sof-firmware linux-firmware))

(define default-bootloader
  (bootloader-configuration
   (bootloader grub-efi-bootloader)
   (targets '("/boot/efi"))
   (keyboard-layout default-keyboard-layout)))

(define default-file-systems '())
(define default-swap-devices '())

(define default-users '())

;; i2c is declared here (not via a service extension) so bfh's i2c
;; supplementary group always validates; ddcutil's udev rule below grants
;; this group access to /dev/i2c-* for external-monitor brightness (DDC/CI).
(define default-groups
  (list (user-group (name "i2c") (system? #t))))

(define default-extra-packages
  (append (map specification->package
               '("openssh"
                 "sway" "niri" "swaylock" "swayidle" "wlgreet"
                 "xorg-server-xwayland" "xwayland-satellite" "alacritty"
                 "pipewire" "wireplumber" "pavucontrol"
                 "wofi" "wl-clipboard" "mako"
                 "network-manager" "network-manager-applet"
                 "brightnessctl" "ddcutil" "git"))
          %stumpwm-packages))

(define default-extra-services
  (list (udev-rules-service 'ddcutil (specification->package "ddcutil"))))
