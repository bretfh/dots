(defsystem "arc"
           :author "bfh"
           :license "BSD 2-Clause"
           :description "Lem configuration for arc"
           :serial t
           :depends-on (
                        ;; "lem-trailing-spaces"
                        ;; "lem-lisp-mode"
                        ;; "lem-legit"
                        ;; "lem-coalton-mode"
                        ;; "lem-vi-mode"
                        ;;"lem-vi-sexp"
                        "lemms"
                        #+todo "lem-lsp-mode")
           :components (
                        (:file "modes/vi")
                        (:file "modes/agent")
                        (:file "modes/lemms")))
;;                        (:file "modes/auto-save")
;;                        (:file "modes/trailing-spaces")
;;                        (:file "modes/lisp-mode")
;;                        (:file "modes/javascript-mode")

