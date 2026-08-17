;;; The 'bfh' channel's package surface.
;;;
;;; This module re-exports custom package definitions kept under
;;; src/dots/packages/ so they're addressable as one entry point.
;;; Cuirass on the builder VM walks this module to emit one job per
;;; re-export (see build-aux/cuirass-jobs.scm).
;;;
;;; Note: re-exporting from (dots packages …) means anyone consuming
;;; this channel via `guix pull` needs the dots load path available.
;;; In practice that's not how it's used today — `guix install -L ~/dots`
;;; on framework/arraniz already finds these packages directly. The
;;; channel exists to give Cuirass a single anchor for substitute builds.

(define-module (dots packages all)
  #:use-module (dots packages stumpwm)
  #:use-module (dots packages guile-hoot)
  #:use-module (dots packages guile-websocket)
  #:use-module (dots packages claude-code)
  #:use-module (dots packages qwen-code)
  #:use-module (dots packages opentofu)
  #:use-module (dots packages ministack)
  #:use-module (dots packages playwright)
  #:use-module (dots packages litestream)
  #:use-module (dots packages brogue-ce)
  #:re-export (stumpwm-dev
               stumpwm-dev+servers
               cl-stumpwm-dev
               guile-hoot-latest
               guile-websocket-fixed
               claude-code
               qwen-code
               opentofu
               ministack
               node-playwright
               node-playwright-core
               litestream
               brogue-ce))
