;;; Entry: the operating-system for this host. The person's module is under users/.
;;;   guix system -L src reconfigure system.scm
(add-to-load-path (dirname (current-filename)))
(use-modules (dots site) (users bfh))
(current-operating-system machines)
