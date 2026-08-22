;;; Entry: guix deploy targets for the lab guests.
;;;   guix deploy -L src fleet.scm   (optionally `-- NAME ...` for a subset)
(use-modules (dots fleet))
(deploy-targets)
