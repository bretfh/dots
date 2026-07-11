(define-module (tree-sitter-commonlisp)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix build-system gnu)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (tree-sitter-commonlisp))

(define-public tree-sitter-commonlisp
  (package
    (name "tree-sitter-commonlisp")
    (version "0.4.1")
    (source (local-file "../../tree-sitter-commonlisp/src"
                        "tree-sitter-commonlisp-src" #:recursive? #t))
    (build-system gnu-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (replace 'build
            (lambda _
              (invoke "gcc" "-shared" "-fPIC" "-I" "." "parser.c"
                      "-o" "libtree-sitter-commonlisp.so")))
          (replace 'install
            (lambda _
              (let ((lib (string-append #$output "/lib/tree-sitter")))
                (mkdir-p lib)
                (install-file "libtree-sitter-commonlisp.so" lib)))))))
    (home-page "https://github.com/tree-sitter-grammars/tree-sitter-commonlisp")
    (synopsis "Tree-sitter grammar for Common Lisp")
    (description "Common Lisp grammar for tree-sitter, built as a shared
library loadable by pine.")
    (license license:expat)))

tree-sitter-commonlisp
