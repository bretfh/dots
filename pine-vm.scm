;;; A VM that logs in the way a person does: gdm offers the pine session, picks
;;; it for bfh, and runs it through a login shell -- which is what starts the
;;; home shepherd, which is what owns the pine daemon. The only way to test that
;;; path without logging out.
;;;
;;;   PINE_VM_HOME=$(guix home -L src build home.scm) \
;;;     guix system vm --image-size=6G -L src -L ~/git/cl/pine/guix pine-vm.scm
;;;
;;; The script it writes runs with 512M and a read-only disk, which is not
;;; enough. Run qemu with its arguments plus -m 6144, snapshot=on, a virtio-gpu,
;;; and -display none with a monitor socket; `screendump FILE -f png' on that
;;; socket is how you see what it drew, and `console=ttyS0' with a serial socket
;;; is how you ask the daemon what it thinks.

(use-modules (gnu) (guix gexp) (gnu services) (gnu services shepherd)
             (dots packages pine-session)
             (dots packages maple-font))
(use-service-modules desktop xorg dbus networking sound)
(use-package-modules fonts fontutils terminals)

(define %home
  (or (getenv "PINE_VM_HOME")
      (error "PINE_VM_HOME unset: guix home -L src build home.scm")))

(define activate-bfh-home
  ;; What `guix home reconfigure' does once on a real machine: put .profile and
  ;; the config files in place. The shepherd is not started here -- there is no
  ;; runtime directory before a login -- and .profile starts it at one.
  (program-file "activate-bfh-home"
    #~(begin
        (setenv "HOME" "/home/bfh")
        (setenv "GUIX_NEW_HOME" #$%home)
        (setenv "GUIX_SYSTEM_IS_RUNNING_HOME_ACTIVATE" "1")
        (let ((pw (getpwnam "bfh")))
          (setgid (passwd:gid pw))
          (setuid (passwd:uid pw)))
        (execl #$(string-append %home "/activate") "activate"))))

(define %pine-is-the-session
  (plain-file "bfh-accounts" "[User]\nSession=pine\nSystemAccount=false\n"))

(operating-system
  (host-name "pine-vm")
  (timezone "Etc/UTC")
  (locale "en_US.utf8")

  (bootloader (bootloader-configuration
               (bootloader grub-bootloader)
               (targets '("/dev/vda"))))
  (file-systems (cons (file-system
                        (mount-point "/")
                        (device "/dev/vda1")
                        (type "ext4"))
                      %base-file-systems))

  (users (cons (user-account
                (name "bfh")
                (comment "pine")
                (group "users")
                (password "")
                (supplementary-groups
                 '("wheel" "audio" "video" "input" "tty")))
               %base-user-accounts))

  (packages (cons* pine-session
                   font-maple-mono-nf font-dejavu fontconfig
                   foot (specification->package "alacritty")
                   %base-packages))

  (services
   (cons*
    (simple-service 'bfh-session-choice activation-service-type
                    #~(begin
                        (mkdir-p "/var/lib/AccountsService/users")
                        (copy-file #$%pine-is-the-session
                                   "/var/lib/AccountsService/users/bfh")))
    (simple-service 'bfh-home shepherd-root-service-type
                    (list (shepherd-service
                           (provision '(bfh-home))
                           (requirement '(user-processes))
                           (one-shot? #t)
                           (documentation "Put bfh's home in place, once.")
                           (start #~(lambda ()
                                      (zero? (system* #$activate-bfh-home)))))))
    (modify-services %desktop-services
      (gdm-service-type
       config => (gdm-configuration
                  (inherit config)
                  (auto-login? #t)
                  (default-user "bfh")
                  (auto-suspend? #f)
                  (wayland? #t)))))))
