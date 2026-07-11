(use-modules (guix profiles) (gnu packages))
(add-to-load-path (string-append (dirname (current-filename)) "/guix"))
(use-modules (tree-sitter-commonlisp) (pine-pty))

(concatenate-manifests
 (list (specifications->manifest
        (list "sbcl"
              "gtk"
              "gobject-introspection"
              "tree-sitter"
              "gtk4-layer-shell"
              "gcc-toolchain"
              "pkg-config"))
       (packages->manifest (list tree-sitter-commonlisp pine-pty))))
