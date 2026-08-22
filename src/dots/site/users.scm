(define-module (dots site users)
  #:use-module (oop goops)
  #:use-module (gnu packages)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services desktop)
  #:use-module (gnu home services ssh)
  #:use-module (gnu home services sound)
  #:use-module (gnu home services xdg)
  #:use-module (gnu services)
  #:use-module (guix gexp)
  #:use-module (dots user)
  #:use-module (dots home services bash)
  #:use-module (dots core)
  #:use-module (dots desktop)
  #:use-module (dots machine)
  #:use-module (dots site desktop)
  #:use-module (dots assets)
  #:use-module (dots packages claude-code)
  #:use-module (dots packages claude-agent-acp)
  #:use-module (dots packages qwen-code)
  #:use-module (dots packages maple-font)
  #:export (<bfh> bfh))

(define-class <bfh> (<user>))
(define bfh (make <bfh> #:name "bfh"))

(define-method (user-comment (u <bfh>) m) "some guy")

;;; Anywhere: I administer my own machines.
(define-method (user-groups (u <bfh>) m) '("wheel"))

;;; On a workstation: a desktop session, and the hardware it needs.
(define-method (user-desktop (u <bfh>) (m <workstation>)) default-desktop)

(define-method (user-groups (u <bfh>) (m <workstation>))
  (append (next-method) '("tty" "lp" "netdev" "audio" "video" "kvm")))

(define-method (user-packages (u <bfh>) (m <workstation>))
  (%packages (user-desktop u m)))

(define-method (user-services (u <bfh>) (m <workstation>))
  (%services (user-desktop u m)))

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
(define %loose-config-files
  `(("common-lisp/source-registry.conf.d/guix.conf"
     ,(local-file (string-append assets-dir
                                 "/common-lisp/source-registry.conf.d/guix.conf")))))

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
                          %loose-config-files))
         (home-bash-service #:config-dir assets-dir #:desktop d))
   (desktop-services d)
   %session-services))
