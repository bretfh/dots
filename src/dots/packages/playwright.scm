(define-module (dots packages playwright)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system node))

(define-public node-playwright-core
  (package
    (name "node-playwright-core")
    (version "1.62.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://registry.npmjs.org/playwright-core/-/"
                           "playwright-core-" version ".tgz"))
       (sha256
        (base32 "004ay2wh60xpmsbw6xfxfh623ab61f5x1lp0ixsbkpfhhghy2jwm"))))
    (build-system node-build-system)
    (arguments (list #:tests? #f))
    (home-page "https://playwright.dev")
    (synopsis "Browser automation library, core")
    (description
     "playwright-core drives Chromium, Firefox and WebKit over their
respective debugging protocols.  The published tarball carries its
JavaScript prebuilt and declares neither dependencies nor install
scripts, so nothing is fetched at build time.  Browsers are not included;
point @code{executablePath} at one from Guix.")
    (license license:asl2.0)))

(define-public node-playwright
  (package
    (name "node-playwright")
    (version "1.62.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://registry.npmjs.org/playwright/-/"
                           "playwright-" version ".tgz"))
       (sha256
        (base32 "167d832ds781n4nmm0wzns904yafbsmpycqngk5nq91bi1m5b0hr"))))
    (build-system node-build-system)
    (arguments (list #:tests? #f))
    (inputs (list node-playwright-core))
    (home-page "https://playwright.dev")
    (synopsis "Browser automation library")
    (description
     "Playwright automates a browser through a single API.  This is the
wrapper over playwright-core; the browser binaries it would normally
download are deliberately absent, so a launch has to name an
@code{executablePath}, such as the @code{ungoogled-chromium} Guix
provides.")
    (license license:asl2.0)))
