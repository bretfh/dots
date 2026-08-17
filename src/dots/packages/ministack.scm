(define-module (dots packages ministack)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system pyproject)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages xml))

(define-public ministack
  (package
    (name "ministack")
    (version "1.4.14")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/ministackorg/ministack/archive/refs/tags/v"
             version ".tar.gz"))
       (file-name (string-append name "-" version ".tar.gz"))
       (sha256
        (base32 "1va1391jcsl4vm140b574gm9kdghbagma7lna5lqjqmsm2hj5mvs"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (delete 'sanity-check)
          (add-after 'wrap 'write-wrapper
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out     (assoc-ref outputs "out"))
                     (bin-dir (string-append out "/bin"))
                     (real    (string-append out "/libexec/ministack/ministack"))
                     (wrapper (string-append bin-dir "/ministack"))
                     (bash    (assoc-ref inputs "bash-minimal")))
                (mkdir-p (string-append out "/libexec/ministack"))
                (rename-file wrapper real)
                (call-with-output-file wrapper
                  (lambda (port)
                    (format port "#!~a/bin/bash~%" bash)
                    (format port "export PERSIST_STATE=\"${PERSIST_STATE:-1}\"~%")
                    (format port "export STATE_DIR=\"${STATE_DIR:-~
${XDG_DATA_HOME:-$HOME/.local/share}/ministack}\"~%")
                    (format port "mkdir -p \"$STATE_DIR\"~%")
                    (format port "exec ~a \"$@\"~%" real)))
                (chmod wrapper #o555)))))))
    (native-inputs (list python-setuptools python-wheel))
    (inputs (list bash-minimal))
    (propagated-inputs
     (list python-defusedxml python-hypercorn python-pyyaml))
    (home-page "https://ministack.org")
    (synopsis "Local AWS emulator")
    (description
     "MiniStack emulates AWS service APIs on a single port, as a drop-in target
for the AWS SDKs, OpenTofu and Terraform.  Services backed only by a control
plane---s3, dynamodb, sns, iam, ec2, route53, ssm, secretsmanager, sts,
kms---need nothing further; those that would otherwise start a backing
container, such as rds, ecs and lambda, record their resources and stay
metadata-only.

Upstream defaults to discarding all state on exit and to a state directory
under /tmp.  The wrapper installed here turns persistence on and keeps state
under XDG_DATA_HOME, so resources outlive a restart and stay consistent with
the tofu state that refers to them.  Both are overridable through
PERSIST_STATE and STATE_DIR.")
    (license license:expat)))
