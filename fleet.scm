;;; Entry: guix deploy targets for the lab guests. The person's module is under users/.
;;;   guix deploy -L src fleet.scm   (optionally `-- NAME ...` for a subset)
(add-to-load-path (dirname (current-filename)))
(use-modules (dots site) (users bfh))
(deploy-targets machines)
