;; -*- lexical-binding: t -*-
(require 'xdg)
;; Set main directories
(setq user-emacs-directory (expand-file-name "emacs/" (xdg-config-home)))
;; Critical: Set native-comp-eln-load-path before anything tries to compile
(when (featurep 'native-compile)
  (let ((eln-cache-dir (expand-file-name "emacs/eln-cache/" (xdg-cache-home))))
    (setq native-comp-eln-load-path (list eln-cache-dir))
    (startup-redirect-eln-cache eln-cache-dir)))
;; Auto-save settings need to be set before auto-save-list loads
(let ((cache-dir (expand-file-name "emacs/" (xdg-cache-home))))
  (make-directory cache-dir t)
  (make-directory (expand-file-name "auto-saves/" cache-dir) t)
  (make-directory (expand-file-name "auto-save-list/" cache-dir) t)
  (setq auto-save-list-file-prefix (expand-file-name "auto-save-list/.saves-" cache-dir)
        auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-saves/" cache-dir) t))))

;; State files
(let ((state-dir (expand-file-name "emacs/" (xdg-state-home))))
  (make-directory state-dir t)
  (setq backup-directory-alist `(("." . ,(expand-file-name "backups/" state-dir)))
        savehist-file (expand-file-name "history" state-dir)
        recentf-save-file (expand-file-name "recentf" state-dir)
        save-place-file (expand-file-name "places" state-dir)
        bookmark-default-file (expand-file-name "bookmarks" state-dir)))

;; Cache files
(let ((cache-dir (expand-file-name "emacs/" (xdg-cache-home))))
  (setq url-configuration-directory (expand-file-name "url" cache-dir)
        url-cache-directory (expand-file-name "url/cache" cache-dir)
        tramp-persistency-file-name (expand-file-name "tramp" cache-dir)
        project-list-file (expand-file-name "projects" cache-dir)))
(setq auto-save-list-file-prefix nil)
(setq package-enable-at-startup nil)
(setq gc-cons-threshold (* 80 1024 1024)
      gc-cons-percentage 0.2
      load-prefer-newer noninteractive
      package-enable-at-startup nil
      native-comp-async-report-warnings-errors nil)
(set-language-environment "UTF-8")
(setq default-input-method nil)
(defvar file-name-handler-alist-old file-name-handler-alist)
(setq file-name-handler-alist nil)
(add-hook 'after-init-hook
          #'(lambda ()
              (setq file-name-handler-alist file-name-handler-alist-old)))

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 1) default-frame-alist)
(push '(tool-bar-position . left) default-frame-alist)
(push '(vertical-scroll-bars . nil) default-frame-alist)
(push '(horizontal-scroll-bars . nil) default-frame-alist)

;; Custom file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
