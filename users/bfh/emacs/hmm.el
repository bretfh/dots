(require 'vc)
(require 'flycheck)
(require 'cider)

(defgroup modern-status-bar nil
  "Modern status bar using tab-bar-mode."
  :prefix "modern-status-bar-"
  :group 'convenience)

(defcustom modern-status-bar-separator (propertize "|" 'face 'modern-status-bar-separator)
  "Separator between status bar elements."
  :type 'sexp
  :group 'modern-status-bar)

(defface modern-status-bar
  '((t (:weight light
        :foreground "#000000"
        :background "#E0E0E0"
        :box (:line-width (12 . 8) :color nil :style flat-button)
        :inherit (variable-pitch default))))
  "Face for the modern status bar."
  :group 'modern-status-bar)

(defface modern-status-bar-separator
  '((t (:foreground "#AEAEAE"
        :height 1.2
        :inherit modern-status-bar)))
  "Face for the modern status bar separator."
  :group 'modern-status-bar)

(deftheme modern-status-bar
  "Modern status bar theme")

(custom-theme-set-faces
 'modern-status-bar
 '(tab-bar ((t (:inherit modern-status-bar))))
 '(tab-bar-tab ((t (:inherit modern-status-bar))))
 '(tab-bar-tab-inactive ((t (:inherit modern-status-bar)))))

(custom-theme-set-variables
 'modern-status-bar
 '(tab-bar-format '(modern-status-bar-format))
 '(tab-bar-separator modern-status-bar-separator))

(setq modern-status-bar-format
      '("%e"
        ;; Git status
        (:eval (when (and vc-mode buffer-file-name)
                 (let ((backend (vc-backend buffer-file-name)))
                   (when backend
                     (format " [%s:%s] "
                             (symbol-name backend)
                             (vc-state buffer-file-name backend))))))
        ;; Flycheck/linting issues
        (:eval (when (bound-and-true-p flycheck-mode)
                 (let* ((count (flycheck-count-errors flycheck-current-errors))
                        (errors (flycheck-error-count-for-kind 'error))
                        (warnings (flycheck-error-count-for-kind 'warning)))
                   (if (or errors warnings)
                       (format " FlyC:[%s/%s] " (or errors 0) (or warnings 0))
                     " FlyC:✓ "))))
        ;; REPL status (for CIDER)
        (:eval (when (bound-and-true-p cider-mode)
                 (format " REPL:%s " (cider--modeline-info))))
        ;; File type and major mode
        " %" mode-name
        ;; Line and column
        (:eval (format " L%l:C%c"))
        ;; Encoding
        " %Z "
        ;; Evil state (if using evil-mode)
        (:eval (when (bound-and-true-p evil-mode)
                 (let ((state (symbol-name evil-state)))
                   (propertize (format " <%s> " state)
                               'face (cond ((eq evil-state 'normal) '(:foreground "green"))
                                           ((eq evil-state 'insert) '(:foreground "red"))
                                           ((eq evil-state 'visual) '(:foreground "orange"))
                                           (t '(:foreground "purple")))))))
        ;; Modified status
        (:eval (if (buffer-modified-p) " [*] " " [-] "))
        ;; Right-align the rest of the mode line
        (:eval (propertize " " 'display '(space :align-to (- right 10))))
        ;; Time
        (:eval (format-time-string "%H:%M"))))

(defun modern-status-bar-format ()
  "Format the modern status bar."
  (let ((status-string (format-mode-line modern-status-bar-format)))
    `((global-mode-line menu-item ,status-string ignore))))

(define-minor-mode modern-status-bar-mode
  "Toggle the modern status bar."
  :global t
  :lighter " MSB"
  :group 'modern-status-bar
  (if modern-status-bar-mode
      (progn
        (setq-default mode-line-format nil)
        (setq tab-bar-format '(modern-status-bar-format))
        (enable-theme 'modern-status-bar)
        (tab-bar-mode 1))
    (setq-default mode-line-format (default-value 'mode-line-format))
    (setq tab-bar-format '(tab-bar-format-tabs tab-bar-format-add-tab))
    (disable-theme 'modern-status-bar)
    (tab-bar-mode -1))
  (force-mode-line-update t))

(defun modern-status-bar--enable-theme (theme)
  "Ensure that the modern-status-bar theme is enabled."
  (when (and (not (eq theme 'modern-status-bar))
             (or (not (member 'modern-status-bar custom-enabled-themes))
                 (eq 'modern-status-bar (car (last custom-enabled-themes)))))
    (enable-theme 'modern-status-bar)
    (tab-bar--update-tab-bar-lines t)))

(add-hook 'enable-theme-functions #'modern-status-bar--enable-theme)

(provide 'modern-status-bar)







;;;;;;;;;;;;;;;;;





(require 'vc)
(require 'flycheck)
(require 'cider)

(defgroup modern-status-bar nil
  "Modern status bar using tab-bar-mode."
  :prefix "modern-status-bar-"
  :group 'convenience)

(defface modern-status-bar
  '((t (:inherit default
        :foreground "#F0F0F0"
        :background "#4B4B4B"
        :box (:line-width (2 . 2) :color nil :style flat-button)
        :height 0.9)))
  "Face for the modern status bar."
  :group 'modern-status-bar)

(defcustom modern-status-bar-height 25
  "Height of the modern status bar in pixels."
  :type 'integer
  :group 'modern-status-bar)

(deftheme modern-status-bar
  "Modern status bar theme")

(custom-theme-set-faces
 'modern-status-bar
 '(tab-bar ((t (:inherit modern-status-bar))))
 '(tab-bar-tab ((t (:inherit modern-status-bar))))
 '(tab-bar-tab-inactive ((t (:inherit modern-status-bar)))))

(custom-theme-set-variables
 'modern-status-bar
 '(tab-bar-format '(modern-status-bar-format)))

(setq modern-status-bar-format
      '("%e"
        (:eval (when (and vc-mode buffer-file-name)
                 (let ((backend (vc-backend buffer-file-name)))
                   (when backend
                     (format " [%s:%s]"
                             (symbol-name backend)
                             (vc-state buffer-file-name backend))))))
        (:eval (when (bound-and-true-p flycheck-mode)
                 (let* ((count (flycheck-count-errors flycheck-current-errors))
                        (errors (flycheck-error-count-for-kind 'error))
                        (warnings (flycheck-error-count-for-kind 'warning)))
                   (if (or errors warnings)
                       (format " FlyC:[%s/%s]" (or errors 0) (or warnings 0))
                     " FlyC:✓"))))
        (:eval (when (bound-and-true-p cider-mode)
                 (format " REPL:%s" (cider--modeline-info))))
        " %" mode-name
        (:eval (format " L%l:C%c"))
        " %Z"
        (:eval (when (bound-and-true-p evil-mode)
                 (let ((state (symbol-name evil-state)))
                   (propertize (format " <%s>" state)
                               'face (cond ((eq evil-state 'normal) '(:foreground "green"))
                                           ((eq evil-state 'insert) '(:foreground "red"))
                                           ((eq evil-state 'visual) '(:foreground "orange"))
                                           (t '(:foreground "purple")))))))
        (:eval (if (buffer-modified-p) " [*]" " [-]"))
        (:eval (propertize " " 'display '(space :align-to (- right 10))))
        (:eval (format-time-string "%H:%M"))))

(defun modern-status-bar-format ()
  "Format the modern status bar."
  (let ((status-string (format-mode-line modern-status-bar-format)))
    `((global-mode-line menu-item ,status-string ignore))))

(defun modern-status-bar--set-face-attributes ()
  "Set face attributes for the modern status bar based on the current theme."
  (let* ((bg (face-background 'default))
         (fg (face-foreground 'default))
         (status-bg (if (color-dark-p bg)
                        (color-lighten-name bg 20)
                      (color-darken-name bg 20)))
         (status-fg (if (color-dark-p status-bg) "#F0F0F0" "#303030")))
    (set-face-attribute 'modern-status-bar nil
                        :foreground status-fg
                        :background status-bg
                        :box `(:line-width (2 . 2) :color ,status-bg :style flat-button))))

(defun modern-status-bar--update-height ()
  "Update the height of the tab bar."
  (set-face-attribute 'tab-bar nil :height modern-status-bar-height))

(define-minor-mode modern-status-bar-mode
  "Toggle the modern status bar."
  :global t
  :lighter " MSB"
  :group 'modern-status-bar
  (if modern-status-bar-mode
      (progn
        (setq-default mode-line-format nil)
        (setq tab-bar-format '(modern-status-bar-format))
        (modern-status-bar--set-face-attributes)
        (modern-status-bar--update-height)
        (enable-theme 'modern-status-bar)
        (tab-bar-mode 1))
    (setq-default mode-line-format (default-value 'mode-line-format))
    (setq tab-bar-format '(tab-bar-format-tabs tab-bar-format-add-tab))
    (disable-theme 'modern-status-bar)
    (tab-bar-mode -1))
  (force-mode-line-update t))

(defun modern-status-bar--handle-theme-change (&rest _)
  "Handle theme changes for the modern status bar."
  (when modern-status-bar-mode
    (modern-status-bar--set-face-attributes)
    (modern-status-bar--update-height)
    (enable-theme 'modern-status-bar)
    (tab-bar--update-tab-bar-lines t)))

(advice-add 'load-theme :after #'modern-status-bar--handle-theme-change)

(provide 'modern-status-bar)
