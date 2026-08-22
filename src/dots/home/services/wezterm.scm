;;; wezterm -- the fallback terminal. Its config is a curated lua file; the
;;; theme is not generated into it.

(define-module (dots home services wezterm)
  #:use-module (oop goops)
  #:use-module (guix gexp)
  #:use-module (dots home component)
  #:use-module (dots assets)
  #:export (<wezterm> wezterm))

(define-class <wezterm> (<terminal>))
(define wezterm (make <wezterm> #:name 'wezterm))

;; wezterm takes the command after `start --', where alacritty takes `-e'.
(define-method (component-exec-flag (c <wezterm>)) "start --")

(define-method (component-config-files (c <wezterm>) desktop)
  `(("wezterm/wezterm.lua"
     ,(local-file (string-append assets-dir
                                 "/wezterm/.config/wezterm/wezterm.lua")))))
