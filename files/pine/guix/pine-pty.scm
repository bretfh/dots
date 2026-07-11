(define-module (pine-pty)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (pine-pty))

(define-public pine-pty
  (package
    (name "pine-pty")
    (version "0.0.1")
    (source (local-file "../lib/pty.c" "pine-pty.c"))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'unpack)
          (replace 'build
            (lambda _
              (copy-file #$(local-file "../lib/pty.c") "pty.c")
              (invoke "gcc" "-shared" "-fPIC" "pty.c" "-lutil"
                      "-o" "libpine-pty.so")))
          (replace 'install
            (lambda _
              (let ((lib (string-append #$output "/lib")))
                (mkdir-p lib)
                (install-file "libpine-pty.so" lib)))))))
    (home-page "https://example.com/pine")
    (synopsis "PTY spawn helper for pine")
    (description "A small shared library that spawns a command under a
pseudo-terminal via forkpty, for pine's terminal buffers.")
    (license license:expat)))

pine-pty
