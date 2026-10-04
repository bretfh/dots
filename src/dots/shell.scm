;;; A shell fills at the tty the role a component fills on the desktop: bash,
;;; zsh and fish answer the same questions, so a user names a list and the head
;;; is the login shell; the tail is installed and configured too. What every
;;; shell is handed is an <environment>: the variables, paths, aliases, scripts
;;; and login step wanted in any shell. Variables go through guix's
;;; setup-environment for the session-starting login shell; PATH is written
;;; twice, there and into each shell's own always-read file, because a script
;;; on PATH has to be found from an ordinary new terminal, not only a login
;;; one. Aliases and the login step are rendered per shell, so an alias is a
;;; word and a command, never shell syntax.

(define-module (dots shell)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:export (<shell> shell-name shell-package shell-program shell-services
            environment environment?
            environment-variables environment-paths environment-aliases
            environment-scripts environment-login
            environment-services
            alias-lines path-export-line))

(define-class <shell> ()
  (name #:init-keyword #:name #:getter shell-name))

(define-generic shell-package)
(define-generic shell-program)
(define-generic shell-services)

(define-method (shell-package (s <shell>))
  "The package that provides S."
  (specification->package (symbol->string (shell-name s))))

(define-method (shell-program (s <shell>))
  "S as a login shell: the program /etc/passwd names."
  (file-append (shell-package s) "/bin/" (symbol->string (shell-name s))))

(define-method (shell-services (s <shell>) env)
  "The home services that write S's own files from ENV."
  '())

(define-record-type* <environment> environment make-environment
  environment?
  (variables environment-variables (default '()))
  (paths     environment-paths     (default '()))
  (aliases   environment-aliases   (default '()))
  (scripts   environment-scripts   (default '()))
  (login     environment-login     (default "")))

(define (alias-lines aliases)
  (string-concatenate
   (map (match-lambda
          ((name . command) (string-append "alias " name "='" command "'\n")))
        aliases)))

(define (script name body)
  (computed-file name
                 #~(begin
                     (call-with-output-file #$output
                       (lambda (port)
                         (display #$(string-append "#!/bin/sh\n" body) port)))
                     (chmod #$output #o555))))

(define (path-variable paths)
  ;; Appended, not prepended: a store-provided binary (guix's own wrapped,
  ;; Guix-compatible build of a program) has to win over a same-named file a
  ;; foreign installer dropped in a personal bin dir, which is often a raw
  ;; binary that cannot run on Guix at all. PATHS is a fallback, not an
  ;; override.
  (if (null? paths)
      '()
      `(("PATH" . ,(string-append "$PATH:" (string-join paths ":"))))))

(define (path-export-line paths)
  "A POSIX `export PATH=...' line appending PATHS after whatever PATH
already is, or an empty string if PATHS is empty. Every shell's own
always-read file gets this, not only the login-gated setup-environment, so a
script on PATH is found from an ordinary new terminal too -- but only once
nothing else on PATH already answers to that name."
  (if (null? paths)
      ""
      (string-append "export PATH=\"$PATH:" (string-join paths ":") "\"\n")))

(define (environment-services env shells)
  (append
   (list (simple-service 'dots-environment
                         home-environment-variables-service-type
                         (append (environment-variables env)
                                 (path-variable (environment-paths env))))
         (simple-service 'dots-scripts home-files-service-type
                         (map (match-lambda
                                ((name . body)
                                 (list (string-append ".local/bin/" name)
                                       (script name body))))
                              (environment-scripts env))))
   (append-map (lambda (s) (shell-services s env)) shells)))
