;;; Nyxt 4 -- keyboard-driven browser, Electron renderer (the v4 series replaced
;;; WebKitGTK with cl-electron driving a host Electron over a socket).
;;;
;;; Shape of this package:
;;;  - CL core builds from a recursive checkout (deps live in _build/ submodules).
;;;  - The only runtime node dep on the launch path is synchronous-socket (the
;;;    cl-electron transport); its small flat closure (synchronous-socket,
;;;    bindings, file-uri-to-path) is delivered on NODE_PATH.  No npm at build.
;;;  - Electron itself is the nonguix electron-36 host, not a node package.
;;;  - slynk is made available to the running image the way nymph is: not baked
;;;    in, but on CL_SOURCE_REGISTRY so config can (asdf:load-system :slynk) and
;;;    (slynk:create-server :port 4005 :dont-close t), then connect SLY.
;;;
;;; Still needs a build on the box to settle:
;;;  - the recursive-checkout sha256 (guix hash -rx, or build once and copy)
;;;  - the synchronous-socket node-gyp build against electron-36 headers
;;;    (node-deps-nyxt) -- the one real native unknown.

(define-module (dots packages nyxt)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages lisp)             ; sbcl
  #:use-module (gnu packages lisp-xyz)         ; sbcl-slynk
  #:use-module (gnu packages node)             ; node-lts
  #:use-module (gnu packages pkg-config)       ; cffi-grovel needs pkg-config
  #:use-module (gnu packages tls)              ; openssl (cl+ssl)
  #:use-module (gnu packages c)                ; libfixposix (iolib)
  #:use-module (gnu packages sqlite)           ; sqlite (cl-sqlite)
  #:use-module (gnu packages enchant)          ; enchant (cl-enchant spellcheck)
  #:use-module (nongnu packages electron)      ; electron-36
  #:use-module (dots packages node-deps-nyxt)) ; synchronous-socket closure

(define %commit "9276cf1d58eee073024e11f6294a8da3d18a6eb5")

(define-public nyxt
  (package
    (name "nyxt")
    (version "4.0.0-pre-3")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             ;; fork of atlas-engineer/nyxt with the build fixes: closer-mop ->
             ;; codeberg (#3712), +mgl-pax, named-readtables@master (#3700),
             ;; makefile install target.  recursive fetch assembles _build/.
             (url "https://github.com/bretfh/nyxt")
             (commit "641fd65824036965e24ed803698977e74b3afd3e")
             (recursive? #t)))
       (file-name (git-file-name name version))
       (sha256 (base32 "1sqxlxhpxpw69p50wxjx3xya42p94nm28wnpbxvdxwjd73z0jfky"))))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      ;; nyxt is a save-lisp-and-die image: SBCL appends the Lisp core to the
      ;; ELF, and `strip' would discard it (leaving a coreless ~440K runtime).
      #:strip-binaries? #f
      #:make-flags
      #~(list "LISP=sbcl"
              "NYXT_RENDERER=electron"
              "NYXT_SUBMODULES=true"
              "NODE_SETUP=false"
              (string-append "NYXT_VERSION=" #$version)
              (string-append "PREFIX=" #$output)
              "DESTDIR=/")
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)

          ;; Guix sets HOME=/homeless-shelter; SBCL/ASDF need a writable cache.
          (add-after 'unpack 'set-home
            (lambda _ (setenv "HOME" "/tmp")))

          ;; cl+ssl / iolib / cl-sqlite dlopen their C libs while the install
          ;; phase's asdf:make loads nyxt, so put them on the loader path.
          (add-after 'set-home 'set-foreign-libs
            (lambda* (#:key inputs #:allow-other-keys)
              (setenv "LD_LIBRARY_PATH"
                      (string-join
                       (map (lambda (lib) (string-append (assoc-ref inputs lib) "/lib"))
                            '("openssl" "libfixposix" "sqlite" "enchant"))
                       ":"))))

          ;; Patch cl-electron: launch the Guix electron directly (not `npm run
          ;; start'), and point server.js + its working dir at the INSTALLED
          ;; tree (the build dir is gone at runtime; asdf:system-* baked it in).
          (add-after 'unpack 'patch-electron-launch
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((ce (string-append #$output "/share/nyxt/_build/cl-electron")))
                (substitute* "_build/cl-electron/source/core.lisp"
                  (("\\(list \"npm\" \"run\" \"start\" \"--\"\\)")
                   (string-append "(list \""
                                  (search-input-file inputs "/bin/electron")
                                  "\")"))
                  (("\\(asdf:system-relative-pathname :cl-electron \"source/server\\.js\"\\)")
                   (string-append "#p\"" ce "/source/server.js\""))
                  (("\\(asdf:system-source-directory :cl-electron\\)")
                   (string-append "#p\"" ce "/\""))))))

          ;; :nyxt/install ships nyxt's lisp source but not cl-electron's node
          ;; tree (server.js); install it and point NASDF_SOURCE_PATH at it so the
          ;; running image finds it instead of the (gone) build dir.
          (add-after 'install 'install-cl-electron
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((asd (car (find-files "/tmp" "^cl-electron\\.asd$")))
                     (src (dirname asd))
                     (dst (string-append (assoc-ref outputs "out")
                                         "/share/nyxt/_build/cl-electron"))
                     (nm  (string-append dst "/source/node_modules")))
                (mkdir-p (dirname dst))
                (copy-recursively src dst)
                ;; server.js does (require 'synchronous-socket'); resolve it and
                ;; its deps via a node_modules next to server.js.
                (mkdir-p nm)
                (for-each
                 (lambda (pkg mod)
                   (symlink (string-append (assoc-ref inputs pkg) "/lib/node_modules/" mod)
                            (string-append nm "/" mod)))
                 '("node-synchronous-socket" "node-bindings" "node-file-uri-to-path")
                 '("synchronous-socket" "bindings" "file-uri-to-path")))))

          (add-after 'install-cl-electron 'wrap
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (define (node-modules name)
                (string-append (assoc-ref inputs name) "/lib/node_modules"))
              (wrap-program (string-append #$output "/bin/nyxt")
                ;; electron on PATH as a runtime backstop
                `("PATH" ":" prefix
                  (,(dirname (search-input-file inputs "/bin/electron"))))
                ;; full synchronous-socket closure so server.js's require()s
                ;; resolve -- flat and complete, no transitive gaps
                `("NODE_PATH" ":" prefix
                  ,(map node-modules
                        '("node-synchronous-socket"
                          "node-bindings"
                          "node-file-uri-to-path")))
                ;; slynk reachable for the running image's ASDF (nymph-style)
                `("CL_SOURCE_REGISTRY" ":" prefix
                  (,(string-append (assoc-ref inputs "sbcl-slynk") "//")))
                ;; where the running image finds its (and cl-electron's) source
                `("NASDF_SOURCE_PATH" = (,(string-append #$output "/share/nyxt")))
                ;; cl+ssl / iolib / cl-sqlite dlopen their C libs at runtime too
                `("LD_LIBRARY_PATH" ":" prefix
                  ,(map (lambda (lib) (string-append (assoc-ref inputs lib) "/lib"))
                        '("openssl" "libfixposix" "sqlite" "enchant")))))))))
    (native-inputs
     (list sbcl
           node-lts
           pkg-config))
    (inputs
     (list electron-36
           sbcl-slynk
           openssl
           libfixposix
           sqlite
           enchant
           node-synchronous-socket-0.0.2
           node-bindings-1.5.0
           node-file-uri-to-path-1.0.0))
    (home-page "https://nyxt.atlas.engineer")
    (synopsis "Keyboard-driven, Lisp-extensible web browser (Electron renderer)")
    (description
     "Nyxt is a keyboard-oriented, infinitely extensible web browser written and
configured in Common Lisp.  Version 4 renders through Electron via cl-electron,
which drives an Electron process over a socket.  slynk is on the load path so a
SLY REPL can be started from the running browser with
@code{(asdf:load-system :slynk)} and @code{(slynk:create-server :port 4005)}.")
    (license license:bsd-3)))

nyxt
