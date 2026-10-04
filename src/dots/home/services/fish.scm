;;; fish is not POSIX: aliases become abbreviations, and the login step runs
;;; under sh rather than being read in.

(define-module (dots home services fish)
  #:use-module (oop goops)
  #:use-module (ice-9 match)
  #:use-module (gnu services)
  #:use-module (gnu home services shells)
  #:use-module (guix gexp)
  #:use-module (dots shell)
  #:export (<fish> fish))

(define-class <fish> (<shell>))
(define fish (make <fish> #:name 'fish))

(define (fish-add-path-line paths)
  ;; Not fish_add_path: it manages fish_user_paths, a universal variable
  ;; that outlives config.fish and that fish re-merges to the FRONT of PATH
  ;; on every start regardless of --append. A plain append to $PATH here,
  ;; every time config.fish runs, is the only way a store-provided binary
  ;; reliably wins over a same-named file a foreign installer dropped in a
  ;; personal bin dir. Also erase fish_user_paths itself, once and for all
  ;; -- any prior fish_add_path call (ours or otherwise) left an entry
  ;; there that would keep winning the race regardless of this line.
  (if (null? paths)
      ""
      (string-append "set -e fish_user_paths\n"
                      "set -x PATH $PATH " (string-join paths " ") "\n")))

(define-method (shell-services (s <fish>) env)
  (list (service home-fish-service-type
                 (home-fish-configuration
                  (package (shell-package s))
                  (abbreviations
                   (map (match-lambda
                          ((name . command)
                           (cons name (string-append "'" command "'"))))
                        (environment-aliases env)))
                  (config
                   (append
                    (let ((line (fish-add-path-line (environment-paths env))))
                      (if (string-null? line) '() (list (plain-file "path" line))))
                    (if (string-null? (environment-login env))
                        '()
                        (list (mixed-text-file
                               "login"
                               "status --is-login; and sh "
                               (plain-file "login.sh" (environment-login env))
                               "\n")))))))))
