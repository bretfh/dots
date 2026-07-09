;;; Node deps for Nyxt's Electron side (cl-electron's server.js).
;;;
;;; server.js top-level require()s only: node builtins, `electron` (the host
;;; nonguix electron-36), and `synchronous-socket`.  The @ghostery/adblocker
;;; and cross-fetch trees in cl-electron's package.json are for the optional
;;; ad-blocker and are never loaded on the launch path, so they are dropped.
;;;
;;; synchronous-socket is a NAN native addon and MUST be compiled against the
;;; Electron node ABI (electron-36-node-headers), not plain node, or it fails
;;; to load inside the Electron process with a NODE_MODULE_VERSION mismatch.

(define-module (dots packages node-deps-nyxt)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix gexp)
  #:use-module (guix build-system node)
  #:use-module (gnu packages python)
  #:use-module (nongnu packages electron))

(define-public node-file-uri-to-path-1.0.0
  (package
    (name "node-file-uri-to-path")
    (version "1.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/TooTallNate/file-uri-to-path")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1qxmmx4iqf11y760bgq1wzr2w2d2mp7g0vdmis4zw80vkzjqyajr"))))
    (build-system node-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'patch-dependencies 'delete-dev-dependencies
            (lambda _
              (modify-json (delete-dev-dependencies)))))))
    (home-page "https://github.com/TooTallNate/file-uri-to-path")
    (synopsis "Convert a file: URI to a file path")
    (description "Convert a file: URI to a file path.")
    (license license:expat)))

(define-public node-bindings-1.5.0
  (package
    (name "node-bindings")
    (version "1.5.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/TooTallNate/node-bindings")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "100gp6kpjvd4j1dqnp0sbjr1hqx5mz7r61q9qy527jyhk9mj47wk"))))
    (build-system node-build-system)
    (arguments (list #:tests? #f))
    (inputs (list node-file-uri-to-path-1.0.0))
    (home-page "https://github.com/TooTallNate/node-bindings")
    (synopsis "Helper module for loading your native module's .node file")
    (description "Helper module for loading your native module's .node file.")
    (license license:expat)))

(define-public node-nan-2.28.0
  (package
    (name "node-nan")
    (version "2.28.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/nodejs/nan")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0m2lv281rg6164dywh3wjlcpk2as1s1y2gn28crqfspviqaaqdz2"))))
    (build-system node-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'patch-dependencies 'delete-dev-dependencies
            (lambda _
              (modify-json (delete-dev-dependencies)))))))
    (home-page "https://github.com/nodejs/nan")
    (synopsis "Native Abstractions for Node.js (C++ addon headers)")
    (description "Native Abstractions for Node.js: C++ header compatibility shim.")
    (license license:expat)))

(define-public node-synchronous-socket-0.0.2
  (package
    (name "node-synchronous-socket")
    (version "0.0.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://registry.npmjs.org/synchronous-socket"
                           "/-/synchronous-socket-" version ".tgz"))
       (sha256
        (base32 "1ki52i8bsgrjgca8aaclx8llnv1b07w99qay0d2jgzsbzsqd20gg"))))
    (build-system node-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'patch-dependencies 'delete-dev-dependencies
            (lambda _
              (modify-json (delete-dev-dependencies))))
          ;; Compile the NAN addon against electron-36's node headers so the
          ;; resulting .node loads in the Electron process, not plain node.
          (add-before 'build 'electron-abi
            (lambda* (#:key inputs #:allow-other-keys)
              ;; nonguix nests the headers under node_headers/ with common.gypi
              ;; in include/node/; node-gyp wants a nodedir with common.gypi at
              ;; its root, so stage a writable copy and link it there.
              (let* ((base (string-append (assoc-ref inputs "electron-node-headers")
                                          "/node_headers"))
                     (dir  (string-append (getcwd) "/.electron-nodedir")))
                (mkdir-p dir)
                (copy-recursively base dir)
                (symlink "include/node/common.gypi"
                         (string-append dir "/common.gypi"))
                (setenv "npm_config_nodedir" dir)
                (setenv "npm_config_runtime" "electron")
                (setenv "npm_config_build_from_source" "true"))))
          ;; node-gyp ships inside npm's bundle (no PATH binary); invoke it
          ;; with node, against electron-36's headers (npm_config_* + --nodedir).
          (replace 'build
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((node (search-input-file inputs "/bin/node"))
                     (node-gyp (string-append
                                (dirname (dirname node))
                                "/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js")))
                (invoke node node-gyp "rebuild"
                        (string-append "--nodedir=" (getenv "npm_config_nodedir")))))))))
    (native-inputs (list node-nan-2.28.0 electron-36-node-headers python))
    (inputs (list node-bindings-1.5.0))
    (home-page "https://www.npmjs.com/package/synchronous-socket")
    (synopsis "Synchronous Unix domain socket addon (cl-electron transport)")
    (description "Synchronous socket interface used by cl-electron to bridge the
Nyxt SBCL image and the Electron process.")
    (license license:bsd-3)))
