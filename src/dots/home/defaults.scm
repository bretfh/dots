;;; Home defaults. The home-environment built in (dots home base) reads every
;;; field via (home-setting 'key). Hosts override via override-<key> in
;;; (dots hosts <host> home).

(define-module (dots home defaults)
  #:use-module (gnu packages)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services desktop)
  #:use-module (gnu home services ssh)
  #:use-module (gnu home services sound)
  #:use-module (gnu home services xdg)
  #:use-module (gnu services)
  #:use-module (guix gexp)
  #:use-module (dots home services bash)
  #:use-module (dots home component)
  #:use-module (dots home desktop)
  #:use-module (dots assets)
  #:use-module (dots packages claude-code)
  #:use-module (dots packages claude-agent-acp)
  #:use-module (dots packages qwen-code)
  #:use-module (dots packages maple-font)
  #:export (default-extra-packages default-packages default-services
            default-theme))

;; Host-specific additions go in (home-overrides). Empty default.
(define default-extra-packages '())

;; Shared theme: comes from the desktop declaration so every consumer
;; (niri, alacritty, ...) draws from one palette.
(define default-theme (desktop-theme default-desktop))


;; Always-present home packages for bfh.
(define default-packages
  (append (list claude-code claude-agent-acp qwen-code font-maple-mono-nf)
          (specifications->packages
           (append
            (desktop-packages default-desktop)
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

;; Everything desktop-shaped comes from the declaration in (dots home desktop):
;; config files from every component it names, daemons from the primaries.
(define default-services
  (append
   (list (service home-xdg-configuration-files-service-type
                  (append (desktop-config-files default-desktop)
                          %loose-config-files))
         (home-bash-service #:config-dir assets-dir #:desktop default-desktop))
   (desktop-services default-desktop)
   %session-services))
