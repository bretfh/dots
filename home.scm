;;; Entry: the home-environment for this host's user. The person's module is under users/.
;;;   guix home -L src reconfigure home.scm
(add-to-load-path (dirname (current-filename)))
(use-modules (dots site) (users bfh))
(current-home machines)
