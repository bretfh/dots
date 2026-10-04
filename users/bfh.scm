;;; bfh: my machines, my user, my desktop and my shells. dots says nothing
;;; about any of this; this file says all of it. Someone else is another file
;;; here beside their own directory of rc files, and the entries name them.

(define-module (users bfh)
  #:use-module (oop goops)
  #:use-module (ice-9 match)
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
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services desktop)
  #:use-module (gnu home services sound)
  #:use-module (gnu home services ssh)
  #:use-module (gnu home services xdg)
  #:use-module (gnu machine ssh)
  #:use-module (guix gexp)
  #:use-module (dots core)
  #:use-module (dots desktop)
  #:use-module (dots home services alacritty)
  #:use-module (dots home services bash)
  #:use-module (dots home services emacs)
  #:use-module (dots home services eww)
  #:use-module (dots home services fish)
  #:use-module (dots home services fuzzel)
  #:use-module (dots home services gtk)
  #:use-module (dots home services gtklock)
  #:use-module (dots home services mako)
  #:use-module (dots home services niri)
  #:use-module (dots home services sill)
  #:use-module (dots home services sway)
  #:use-module (dots home services swaybg)
  #:use-module (dots home services swayidle)
  #:use-module (dots home services vim)
  #:use-module (dots home services waybar)
  #:use-module (dots home services wezterm)
  #:use-module (dots home services zsh)
  #:use-module (dots input)
  #:use-module (dots lab network)
  #:use-module (dots lab services lan-forward)
  #:use-module (dots machine)
  #:use-module (dots packages claude-agent-acp)
  #:use-module (dots packages claude-code)
  #:use-module (dots packages litestream)
  #:use-module (dots packages maple-font)
  #:use-module (dots packages opentofu)
  #:use-module (dots packages sill-session)
  #:use-module (dots packages qwen-code)
  #:use-module (dots packages stumpwm)
  #:use-module (dots shell)
  #:use-module (dots system services lgeh)
  #:use-module (dots theme ef-dream)
  #:use-module (dots user)
  #:export (machines %keyboard))

;;; The checkout this file is in, and my rc files beside it.
(define %root
  (dirname (dirname (canonicalize-path (search-path %load-path "users/bfh.scm")))))
(define %assets (string-append %root "/users/bfh"))


;;; What bfh's machines share beyond the archetypes: the clock, the keyboard,
;;; the workstation's system packages, and the lab's ssh and substitutes.

(define %keyboard (keyboard (layout "us") (options '("ctrl:swapcaps"))))

(define-class <bfh-workstation> (<workstation>))

(define-method (machine-timezone (m <bfh-workstation>)) "America/New_York")
(define-method (machine-keyboard (m <bfh-workstation>)) %keyboard)
(define-method (machine-packages (m <bfh-workstation>))
  (append (list (sill-session %keyboard))
          (map specification->package
               '("openssh"
                 "sway" "niri" "swaylock" "swayidle" "wlgreet"
                 "xorg-server-xwayland" "xwayland-satellite" "alacritty"
                 "pipewire" "wireplumber" "pavucontrol"
                 "wofi" "wl-clipboard" "mako"
                 "network-manager" "network-manager-applet"
                 "brightnessctl" "ddcutil" "git"))
          %stumpwm-packages))


(define %builder-substitute-url "http://10.20.0.10:8080")

(define-class <lab-guest> (<guest>))

;; The builder cannot pull substitutes from itself.
(define-generic guest-bootstrap?)
(define-method (guest-bootstrap? (m <lab-guest>)) #f)

(define-method (machine-timezone (m <lab-guest>)) "America/New_York")
(define-method (machine-keyboard (m <lab-guest>)) %keyboard)
(define-method (machine-ssh (m <lab-guest>))
  (machine-ssh-configuration
   (inherit (next-method))
   (port 2226)
   (identity (string-append (getenv "HOME") "/.ssh/id_ed25519"))))

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
      (append (list (local-file "bfh/keys/builder.pub"))
              (cons (local-file "../src/dots/keys/nonguix.pub")
                    %default-authorized-guix-keys))))))

;; After the guest's dhcp comes ssh, then the base with the lab's substitutes.
(define-method (machine-services (m <lab-guest>))
  (match (next-method)
    ((dhcp . base)
     (cons* dhcp
            (service openssh-service-type
                     (openssh-configuration
                      (port-number 2226)
                      (password-authentication? #f)
                      (permit-root-login 'prohibit-password)
                      (authorized-keys
                       `(("bfh"  ,(local-file "bfh/keys/bfh.pub"))
                         ("root" ,(local-file "bfh/keys/bfh.pub"))))))
            (modify-services base
              (guix-service-type config => ((guest-substitutes m) config)))))))



(define default-desktop
  (desktop
   (compositors (list niri sway))
   (bars        (list sill eww waybar))
   (pickers     (list fuzzel))
   (terminals   (list alacritty wezterm))
   (editors     (list emacs vim))
   (notifiers   (list mako))
   (locks       (list gtklock))
   (idlers      (list swayidle))
   (wallpapers  (list swaybg))
   (toolkits    (list gtk))
   (theme       ef-dream)
   (keyboard    %keyboard)
   (assets      %assets)))


(define-class <bfh> (<user>))

(define bfh (make <bfh> #:name "bfh"))
(define-method (user-comment (u <bfh>) m) "some guy")
(define-method (user-groups (u <bfh>) m) '("wheel"))
(define-method (user-desktop (u <bfh>) (m <workstation>)) default-desktop)
(define-method (user-groups (u <bfh>) (m <workstation>))
  (append (next-method) '("tty" "lp" "netdev" "audio" "video" "kvm")))
(define-method (user-packages (u <bfh>) (m <workstation>))
  (%packages (user-desktop u m)))
(define-method (user-services (u <bfh>) (m <workstation>))
  (%services (user-desktop u m)))
(define-method (user-shells (u <bfh>) (m <workstation>)) (list bash zsh fish))

(define (reconfigure command entry)
  (string-append "exec " command
                 " -L " %root "/src"
                 " -L \"${SILL:-$HOME/git/cl/sill}/guix\""
                 " reconfigure " %root "/" entry " \"$@\"\n"))

(define-method (user-environment (u <bfh>) m)
  (environment
   (paths '("$HOME/.local/bin" "$HOME/.roswell/bin"))
   (aliases '(("ll" . "ls -l")
              ("la" . "ls -la")))
   (scripts `(("update-system" . ,(reconfigure "sudo -E guix system" "system.scm"))
              ("update-home"   . ,(reconfigure "guix home" "home.scm"))))))

(define-method (user-environment (u <bfh>) (m <workstation>))
  (let ((d (user-desktop u m)))
    (environment
     (inherit (next-method))
     (variables (desktop-environment d))
     (login (desktop-login-script d)))))

(define (%packages d)
  (append (list claude-code claude-agent-acp qwen-code font-maple-mono-nf)
          (specifications->packages
           (append
            (desktop-packages d)
            (list "guile" "guile-colorized" "guile-readline" "babashka"
                  "coreutils" "nushell" "xz" "make" "ncurses"
                  "pkg-config" "mako" "libnotify" "slurp" "grimshot"
                  "gtklock" "swayidle"
                  "wl-clipboard" "swaybg" "playerctl" "mpv" "git" "ripgrep" "cl-trial"
                  "sbcl-trial" "fd" "jq" "font-spleen" "font-fira-code"
                  "font-jetbrains-mono" "font-liberation" "font-dejavu"
                  "font-google-noto" "font-terminus" "adwaita-icon-theme"
                  "gnome-themes-extra" "htop" "tmux" "curl" "wget"
                  "llvm@15" "gopls" "ruby-solargraph" "gdb" "zlib" "sbcl"
                  "sbcl-slynk" "bind" "unzip" "zip" "godot" "rust-analyzer"
                  "rust:cargo" "node" "clojure-tools" "clojure"
                  "clj-kondo" "clojure-lsp" "man-db" "vlc" "mosh"
                  "rust" "elixir" "python" "automake" "autoconf" "perl"
                  "openjdk@18.0.2:jdk"
                  "tree-sitter-python" "tree-sitter-markdown"
                  "tree-sitter-scheme" "tree-sitter-typescript"
                  "tree-sitter-javascript" "tree-sitter-rust"
                  "tree-sitter-ruby" "tree-sitter-html" "tree-sitter-php"
                  "tree-sitter-org" "tree-sitter-json" "tree-sitter-java"
                  "tree-sitter-haskell" "tree-sitter-css" "tree-sitter-go"
                  "tree-sitter-dockerfile" "tree-sitter-elixir"
                  "tree-sitter-clojure" "tree-sitter-cpp" "tree-sitter-c"
                  "tree-sitter" "imagemagick" "niri" "gimp"
                  "aspell-dict-en" "hunspell-dict-en-us" "hunspell" "ispell"
                  "aspell" "leiningen" "libvterm" "pavucontrol"
                  "mupen64plus-ui-console" "mupen64plus-core"
                  "mupen64plus-audio-sdl" "mupen64plus-input-sdl"
                  "mupen64plus-video-z64" "book-sicp" "lem" "tiled"
                  "gammastep" "guile-ares-rs" "retroarch-assets"
                  "libretro-mupen64plus-nx" "retroarch" "flatpak")))))

;; Config files that belong to no desktop component -- they are not a bar or a
;; terminal, just files this user wants in ~/.config.
(define (%loose-config-files d)
  `(("common-lisp/source-registry.conf.d/guix.conf"
     ,(desktop-asset d "common-lisp/source-registry.conf.d/guix.conf"))))

;; Session plumbing: not desktop components, so they are listed rather than
;; derived. Every entry here is something no choice of bar or compositor
;; changes.
(define %session-services
  (list (service home-dbus-service-type)
        (service home-pipewire-service-type)
        (service home-ssh-agent-service-type)
        (service home-openssh-service-type
                 (home-openssh-configuration
                  (add-keys-to-agent "yes")))))

(define (%services d)
  (append
   (list (service home-xdg-configuration-files-service-type
                  (append (desktop-config-files d)
                          (%loose-config-files d))))
   (desktop-services d)
   %session-services))


(define-class <framework> (<bfh-workstation>))

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


(define-class <arraniz> (<bfh-workstation>))

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
;; brightness.
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


;;; builder -- guest; signed substitute server (guix publish) on :8080

(define-class <builder> (<lab-guest>))

(define-method (machine-users (m <builder>)) (list bfh))
(define-method (machine-host-name (m <builder>)) "builder")
(define-method (guest-bootstrap? (m <builder>)) #t)
(define-method (machine-services (m <builder>))
  (cons (service guix-publish-service-type
                 (guix-publish-configuration
                  (host "0.0.0.0")
                  (port 8080)
                  (cache "/var/cache/publish")
                  (compression '(("zstd" 3)))))
        (next-method)))


;;; media -- guest; Jellyfin in a container, host music share at /srv/media

(define-class <media> (<lab-guest>))

(define-method (machine-users (m <media>)) (list bfh))

(define-method (machine-host-name (m <media>)) "media")

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


;;; Every machine this file manages. A guest carries the address `guix deploy'
;;; reaches it on; a workstation has none.
(define machines
  (list (make <framework>)
        (make <arraniz>)
        (make <builder> #:address "10.20.0.10")
        (make <media>   #:address "10.20.0.11")))
