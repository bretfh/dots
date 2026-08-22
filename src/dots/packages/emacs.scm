(define-module (dots packages emacs)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system emacs)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (emacs-super-save))

(define-public emacs-super-save
  (let ((commit "886b5518c8a8b4e1f5e59c332d5d80d95b61201d")
        (revision "0"))
    (package
      (name "emacs-super-save")
      (version (git-version "0.3.0" revision commit))
      (source
       (origin
         (uri (git-reference
               (url "https://github.com/bbatsov/super-save")
               (commit commit)))
         (method git-fetch)
         (sha256
          (base32 "1w62sd1vcn164y70rgwgys6a8q8mwzplkiwqiib8vjzqn87w0lqv"))
         (file-name (git-file-name name version))))
      (build-system emacs-build-system)
      (home-page "https://github.com/bbatsov/super-save")
      (synopsis "Emacs package for automatic saving of buffers")
      (description
       "super-save auto-saves your buffers, when certain events happen: you
switch between buffers, an Emacs frame loses focus, etc.  You can think of
it as an enhanced `auto-save-mode'")
      (license license:gpl3+))))

