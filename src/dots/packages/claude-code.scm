(define-module (dots packages claude-code)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)        ;; glibc
  #:use-module (gnu packages bash)        ;; bash-minimal for wrapper
  #:use-module (gnu packages gcc)         ;; gcc "lib"
  #:use-module (gnu packages nss))        ;; nss-certs

(define-public claude-code
  (package
    (name "claude-code")
    (version "2.1.220")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://registry.npmjs.org/@anthropic-ai/claude-code-linux-x64"
             "/-/claude-code-linux-x64-" version ".tgz"))
       (sha256
        (base32 "03dd4x9c0p9r0nrimyjywian9ha57kl05nphxb7dblfkwv5f5li5"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:validate-runpath? #f
      #:strip-binaries? #f
      #:install-plan
      #~(quote (("claude" "libexec/claude-code/claude")))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'write-wrapper
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out       (assoc-ref outputs "out"))
                     (real      (string-append out "/libexec/claude-code/claude"))
                     (bin-dir   (string-append out "/bin"))
                     (wrapper   (string-append bin-dir "/claude"))
                     (bash      (assoc-ref inputs "bash-minimal"))
                     (glibc     (assoc-ref inputs "glibc"))
                     (gcc-lib   (assoc-ref inputs "gcc-lib"))
                     (nss       (assoc-ref inputs "nss-certs"))
                     (loader    (string-append glibc "/lib/ld-linux-x86-64.so.2"))
                     (libpath   (string-append glibc "/lib:" gcc-lib "/lib"))
                     (certs     (string-append nss "/etc/ssl/certs"))
                     (ca-file   (string-append certs "/ca-certificates.crt")))
                (chmod real #o555)
                (mkdir-p bin-dir)
                (call-with-output-file wrapper
                  (lambda (port)
                    (format port "#!~a/bin/bash~%" bash)
                    (format port "export SSL_CERT_DIR=~a~%" certs)
                    (format port "export SSL_CERT_FILE=~a~%" ca-file)
                    (format port "exec ~a --library-path ~a ~a \"$@\"~%"
                            loader libpath real)))
                (chmod wrapper #o555)))))))
    (inputs
     `(("bash-minimal" ,bash-minimal)
       ("glibc"        ,glibc)
       ("gcc-lib"      ,gcc "lib")
       ("nss-certs"    ,nss-certs)))
    (home-page "https://claude.com/claude-code")
    (synopsis "Anthropic Claude Code CLI (prebuilt native binary)")
    (description
     "Claude Code command-line interface from Anthropic, packaged from the
prebuilt @@code{@@anthropic-ai/claude-code-linux-x64} npm tarball.  The native
binary is left untouched; a shell wrapper invokes it via the Guix dynamic
loader with an explicit @@code{--library-path}, avoiding patchelf which breaks
Bun-compiled binaries.")
    (license license:expat)))
