;;; Cuirass jobset spec for the private 'bfh' channel.
;;;
;;; The 'bfh' channel re-exports custom packages from src/dots/packages/ and
;;; is published at https://github.com/bretfh/dots (module root 'src/'
;;; per .guix-channel).
;;;
;;; The jobs are emitted by src/dots/ci/cuirass-jobs.scm -- one job per
;;; re-exported package.

(define-module (dots lab services cuirass-spec)
  #:use-module (guix gexp)
  #:export (%bfh-cuirass-specs))

;; load-path "src" for the bfh input puts the channel module root on the
;; load path so (dots ci cuirass-jobs) and (dots packages ...) resolve.
(define %bfh-cuirass-specs
  #~(list
     '((#:name . "bfh")
       (#:load-path-inputs    . ("guix" "bfh"))
       (#:package-path-inputs . ("bfh"))
       (#:proc-input          . "bfh")
       (#:proc-file           . "src/dots/ci/cuirass-jobs.scm")
       (#:proc                . cuirass-jobs)
       (#:inputs
        . (((#:name      . "guix")
            (#:url       . "https://git.savannah.gnu.org/git/guix.git")
            (#:load-path . ".")
            (#:branch    . "master"))
           ((#:name      . "bfh")
            (#:url       . "https://github.com/bretfh/dots")
            (#:load-path . "src")
            (#:branch    . "main"))))
       (#:build-outputs . ()))))
