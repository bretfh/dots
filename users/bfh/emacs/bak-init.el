;; -*- lexical-binding: t -*-

(defconst rez-ext (expand-file-name "lisp" user-emacs-directory)
  "Directory from which we load extended features.")

(setq custom-file (expand-file-name "custom.el" rez-ext))

(fset #'display-startup-echo-area-message #'ignore)
(fset 'yes-or-no-p 'y-or-n-p)
(setq inhibit-startup-message           t
      inhibit-default-init              t
      inhibit-startup-echo-area-message user-login-name)
(setq kill-buffer-query-functions
      (delq 'process-kill-buffer-query-function
	    kill-buffer-query-functions))

(add-to-list 'load-path rez-ext)
(require 'rez-pkg-mgr)
(cond
 ((eq system-type 'gnu/linux)
  (require 'rez-linux))
 ((eq system-type 'darwin)
  (require 'rez-macos))
 ((eq system-type 'openbsd)))
(require 'rez-modeline)
(require 'rez-ui)
(require 'rez-editor)
(require 'rez-completions)
(require 'rez-lsp)
;;(require 'rez-bullshit)
(require 'rez-notes)
(require 'rez-term)
(require 'rez-dired)
(require 'rez-misc)
;;(require 'rez-fns)
;;(require 'rez-multimedia)
(load custom-file)

;;(setq global-mode-line-format
;;      '("%e"
;;        ;; Git status
;;        (:eval (when (and vc-mode buffer-file-name)
;;                 (let ((backend (vc-backend buffer-file-name)))
;;                   (when backend
;;                     (format " [%s:%s] "
;;                             (symbol-name backend)
;;                             (vc-state buffer-file-name backend))))))
;;        ;; Flycheck/linting issues
;;        (:eval (when (bound-and-true-p flycheck-mode)
;;                 (let* ((count (flycheck-count-errors flycheck-current-errors))
;;                        (errors (flycheck-error-count-for-kind 'error))
;;                        (warnings (flycheck-error-count-for-kind 'warning)))
;;                   (if (or errors warnings)
;;                       (format " FlyC:[%s/%s] " (or errors 0) (or warnings 0))
;;                     " FlyC:✓ "))))
;;        ;; REPL status (for CIDER)
;;        (:eval (when (bound-and-true-p cider-mode)
;;                 (format " REPL:%s " (cider--modeline-info))))
;;        ;; File type and major mode
;;        " %" mode-name
;;        ;; Line and column
;;        (:eval (format " L%l:C%c")
;;        ;; Encoding
;;        " %Z "
;;        ;; Evil state (if using evil-mode)
;;        (:eval (when (bound-and-true-p evil-mode)
;;                 (let ((state (symbol-name evil-state)))
;;                   (propertize (format " <%s> " state)
;;                               'face (cond ((eq evil-state 'normal) '(:foreground "green"))
;;                                           ((eq evil-state 'insert) '(:foreground "red"))
;;                                           ((eq evil-state 'visual) '(:foreground "orange"))
;;                                           (t '(:foreground "purple")))))))
;;        
;;        ;; Modified status
;;        (:eval (if (buffer-modified-p) " [*] " " [-] "))
;;        
;;        ;; Right-align the rest of the mode line
;;        (:eval (propertize " " 'display '(space :align-to (- right 10))))
;;        
;;        ;; Time
;;        (:eval (format-time-string "%H:%M"))))
;;
;;;; Set the new format for the global mode line
;;(setq-default global-mode-line-format global-mode-line-format)
(setq tab-bar-show t)

;; Taken from https://andreyor.st/posts/2020-05-10-making-emacs-tabs-look-like-in-atom/
;; https://github.com/andreyorst/dotfiles/blob/740d346088ce5a51804724659a895d13ed574f81/.config/emacs/README.org#tabline

(defun my/set-tab-theme ()
  (let ((bg (face-attribute 'mode-line :background))
        (fg (face-attribute 'default :foreground))
	(hg (face-attribute 'default :background))
        (base (face-attribute 'mode-line :background))
        (box-width (/ (line-pixel-height) 2)))
    (set-face-attribute 'tab-line nil
			:background base
			:foreground fg
			:height 0.8
			:inherit nil
			:box (list :line-width -1 :color base))
    (set-face-attribute 'tab-line-tab nil
			:foreground fg
			:background bg
			:weight 'normal
			:inherit nil
			:box (list :line-width box-width :color bg))
    (set-face-attribute 'tab-line-tab-inactive nil
			:foreground fg
			:background base
			:weight 'normal
			:inherit nil
			:box (list :line-width box-width :color base))
    (set-face-attribute 'tab-line-highlight nil
			:foreground fg
			:background hg
			:weight 'normal
			:inherit nil
			:box (list :line-width box-width :color hg))
    (set-face-attribute 'tab-line-tab-current nil
			:foreground fg
			:background hg
			:weight 'normal
			:inherit nil
			:box (list :line-width box-width :color hg))))

(defun my/tab-line-name-buffer (buffer &rest _buffers)
  "Create name for tab with padding and truncation.

If buffer name is shorter than `tab-line-tab-max-width' it gets
centered with spaces, otherwise it is truncated, to preserve
equal width for all tabs.  This function also tries to fit as
many tabs in window as possible, so if there are no room for tabs
with maximum width, it calculates new width for each tab and
truncates text if needed.  Minimal width can be set with
`tab-line-tab-min-width' variable."
  (with-current-buffer buffer
    (let* ((window-width (window-width (get-buffer-window)))
           (tab-amount (length (tab-line-tabs-window-buffers)))
           (window-max-tab-width (if (>= (* (+ tab-line-tab-max-width 3) tab-amount) window-width)
                                     (/ window-width tab-amount)
                                   tab-line-tab-max-width))
           (tab-width (- (cond ((> window-max-tab-width tab-line-tab-max-width)
                                tab-line-tab-max-width)
                               ((< window-max-tab-width tab-line-tab-min-width)
                                tab-line-tab-min-width)
                               (t window-max-tab-width))
                         3)) ;; compensation for ' x ' button
           (buffer-name (string-trim (buffer-name)))
           (name-width (length buffer-name)))
      (if (>= name-width tab-width)
          (concat  " " (truncate-string-to-width buffer-name (- tab-width 2)) "…")
        (let* ((padding (make-string (+ (/ (- tab-width name-width) 2) 1) ?\s))
               (buffer-name (concat padding buffer-name)))
          (concat buffer-name (make-string (- tab-width (length buffer-name)) ?\s)))))))

(defun tab-line-close-tab (&optional e)
  "Close the selected tab.

If tab is presented in another window, close the tab by using
`bury-buffer` function.  If tab is unique to all existing
windows, kill the buffer with `kill-buffer` function.  Lastly, if
no tabs left in the window, it is deleted with `delete-window`
function."
  (interactive "e")
  (let* ((posnp (event-start e))
         (window (posn-window posnp))
         (buffer (get-pos-property 1 'tab (car (posn-string posnp)))))
    (with-selected-window window
      (let ((tab-list (tab-line-tabs-window-buffers))
            (buffer-list (flatten-list
                          (seq-reduce (lambda (list window)
                                        (select-window window t)
                                        (cons (tab-line-tabs-window-buffers) list))
                                      (window-list) nil))))
        (select-window window)
        (if (> (seq-count (lambda (b) (eq b buffer)) buffer-list) 1)
            (progn
              (if (eq buffer (current-buffer))
                  (bury-buffer)
                (set-window-prev-buffers window (assq-delete-all buffer (window-prev-buffers)))
                (set-window-next-buffers window (delq buffer (window-next-buffers))))
              (unless (cdr tab-list)
                (ignore-errors (delete-window window))))
          (and (kill-buffer buffer)
               (unless (cdr tab-list)
                 (ignore-errors (delete-window window)))))))))

(defcustom tab-line-tab-min-width 10
  "Minimum width of a tab in characters."
  :type 'integer
  :group 'tab-line)

(defcustom tab-line-tab-max-width 30
  "Maximum width of a tab in characters."
  :type 'integer
  :group 'tab-line)

(use-package tab-line
  :ensure nil
  :config

  (setq tab-line-close-button-show t
        tab-line-new-button-show nil
        tab-line-separator ""
        tab-line-tab-name-function #'my/tab-line-name-buffer
        tab-line-right-button (propertize (if (char-displayable-p ?▶) " ▶ " " > ")
                                          'keymap tab-line-right-map
                                          'mouse-face 'tab-line-highlight
                                          'help-echo "Click to scroll right")
        tab-line-left-button (propertize (if (char-displayable-p ?◀) " ◀ " " < ")
                                         'keymap tab-line-left-map
                                         'mouse-face 'tab-line-highlight
                                         'help-echo "Click to scroll left")
        tab-line-close-button (propertize (if (char-displayable-p ?×) " × " " x ")
                                          'keymap tab-line-tab-close-map
                                          'mouse-face 'tab-line-close-highlight
                                          'help-echo "Click to close tab"))

  (my/set-tab-theme)
  ;;(dolist (mode '(ediff-mode process-menu-mode term-mode vterm-mode))
  ;;(add-to-list 'tab-line-exclude-modes mode))
  (dolist (mode '(ediff-mode process-menu-mode))
    (add-to-list 'tab-line-exclude-modes mode))
  )

;; (defgroup global-mode-line nil
;;   "Enable mode-line in tab-bar-lines."
;;   :prefix "global-mode-line-"
;;   :group 'convenience)

;; (define-minor-mode global-mode-line-mode
;;   "Display mode-line in tab-bar-lines while keeping tab-line-mode active."
;;   :global t
;;   :lighter " GML"
;;   :group 'global-mode-line
;;   (if global-mode-line-mode
;;       (progn
;;         (setq-default mode-line-format nil)
;;         (setq tab-bar-format '(tab-bar-format-global-mode-line))
;;         (tab-bar-mode 1))
;;     (setq-default mode-line-format (copy-sequence global-mode-line-format))
;;     (setq tab-bar-format '(tab-bar-format-tabs tab-bar-format-add-tab))
;;     (tab-bar-mode -1)))
;; (defun tab-bar-format-global-mode-line ()
;;   "Display the global mode line in the tab bar."
;;   (let ((global-mode-line (format-mode-line global-mode-line-format)))
;;     `((global-mode-line menu-item ,global-mode-line ignore))))
;; (provide 'global-mode-line)

(global-tab-line-mode t)




;; (require 'vc)
;; (require 'flycheck)
;; (require 'cider)

;; (defgroup modern-status-bar nil
;;   "Modern status bar using tab-bar-mode."
;;   :prefix "modern-status-bar-"
;;   :group 'convenience)

;; (defface modern-status-bar
;;   '((t (:inherit default
;;         :foreground "#F0F0F0"
;;         :background "#4B4B4B"
;;         :box (:line-width (2 . 2) :color nil :style flat-button)
;;         :height 0.9)))
;;   "Face for the modern status bar."
;;   :group 'modern-status-bar)

;; (defcustom modern-status-bar-height 25
;;   "Height of the modern status bar in pixels."
;;   :type 'integer
;;   :group 'modern-status-bar)

;; (deftheme modern-status-bar
;;   "Modern status bar theme")

;; (custom-theme-set-faces
;;  'modern-status-bar
;;  '(tab-bar ((t (:inherit modern-status-bar))))
;;  '(tab-bar-tab ((t (:inherit modern-status-bar))))
;;  '(tab-bar-tab-inactive ((t (:inherit modern-status-bar)))))

;; (custom-theme-set-variables
;;  'modern-status-bar
;;  '(tab-bar-format '(modern-status-bar-format)))

;; (setq modern-status-bar-format
;;       '("%e"
;;         (:eval (when (and vc-mode buffer-file-name)
;;                  (let ((backend (vc-backend buffer-file-name)))
;;                    (when backend
;;                      (format " [%s:%s]"
;;                              (symbol-name backend)
;;                              (vc-state buffer-file-name backend))))))
;;         (:eval (when (bound-and-true-p flycheck-mode)
;;                  (let* ((count (flycheck-count-errors flycheck-current-errors))
;;                         (errors (flycheck-error-count-for-kind 'error))
;;                         (warnings (flycheck-error-count-for-kind 'warning)))
;;                    (if (or errors warnings)
;;                        (format " FlyC:[%s/%s]" (or errors 0) (or warnings 0))
;;                      " FlyC:✓"))))
;;         (:eval (when (bound-and-true-p cider-mode)
;;                  (format " REPL:%s" (cider--modeline-info))))
;;         " %" mode-name
;;         (:eval (format " L%l:C%c"))
;;         " %Z"
;;         (:eval (when (bound-and-true-p evil-mode)
;;                  (let ((state (symbol-name evil-state)))
;;                    (propertize (format " <%s>" state)
;;                                'face (cond ((eq evil-state 'normal) '(:foreground "green"))
;;                                            ((eq evil-state 'insert) '(:foreground "red"))
;;                                            ((eq evil-state 'visual) '(:foreground "orange"))
;;                                            (t '(:foreground "purple")))))))
;;         (:eval (if (buffer-modified-p) " [*]" " [-]"))
;;         (:eval (propertize " " 'display '(space :align-to (- right 10))))
;;         (:eval (format-time-string "%H:%M"))))

;; (defun modern-status-bar-format ()
;;   "Format the modern status bar."
;;   (let ((status-string (format-mode-line modern-status-bar-format)))
;;     `((global-mode-line menu-item ,status-string ignore))))

;; (defun modern-status-bar--set-face-attributes ()
;;   "Set face attributes for the modern status bar based on the current theme."
;;   (let* ((bg (face-background 'default nil t))
;;          (fg (face-foreground 'default nil t))
;;          (bg-value (color-values bg))
;;          (fg-value (color-values fg))
;;          (dark-theme (and bg-value fg-value (< (apply '+ bg-value) (apply '+ fg-value))))
;;          (status-bg (if dark-theme
;;                         (color-lighten-name (or bg "#000000") 20)
;;                       (color-darken-name (or bg "#FFFFFF") 20)))
;;          (status-fg (if dark-theme "#F0F0F0" "#303030")))
;;     (set-face-attribute 'modern-status-bar nil
;;                         :foreground status-fg
;;                         :background status-bg
;;                         :box `(:line-width (2 . 2) :color ,status-bg :style flat-button))))

;; (defun modern-status-bar--update-height ()
;;   "Update the height of the tab bar."
;;   (set-face-attribute 'tab-bar nil :height modern-status-bar-height))

;; (define-minor-mode modern-status-bar-mode
;;   "Toggle the modern status bar."
;;   :global t
;;   :lighter " MSB"
;;   :group 'modern-status-bar
;;   (if modern-status-bar-mode
;;       (progn
;;         (setq-default mode-line-format nil)
;;         (setq tab-bar-format '(modern-status-bar-format))
;;         (modern-status-bar--set-face-attributes)
;;         (modern-status-bar--update-height)
;;         (enable-theme 'modern-status-bar)
;;         (tab-bar-mode 1))
;;     (setq-default mode-line-format (default-value 'mode-line-format))
;;     (setq tab-bar-format '(tab-bar-format-tabs tab-bar-format-add-tab))
;;     (disable-theme 'modern-status-bar)
;;     (tab-bar-mode -1))
;;   (force-mode-line-update t))

;; (defun modern-status-bar--handle-theme-change (&rest _)
;;   "Handle theme changes for the modern status bar."
;;   (when modern-status-bar-mode
;;     (modern-status-bar--set-face-attributes)
;;     (modern-status-bar--update-height)
;;     (enable-theme 'modern-status-bar)
;;     (tab-bar--update-tab-bar-lines t)))

;; (advice-add 'load-theme :after #'modern-status-bar--handle-theme-change)

;; (provide 'modern-status-bar)
;;;;;;;;;;;;
(require 'vc)
(require 'flycheck)
(require 'cider)

(defgroup modern-status-bar nil
  "Modern status bar using tab-bar-mode."
  :prefix "modern-status-bar-"
  :group 'convenience)

(defface modern-status-bar
  '((t (:inherit default
        :family "Arial"  ; or any other proportional font you prefer
        :height 110
        :foreground "#E0E0E0"
        :background "#404040"
        :box (:line-width (24 . 8) :color "#404040" :style flat-button))))
  "Face for the modern status bar."
  :group 'modern-status-bar)

(defcustom modern-status-bar-height 270
  "Height of the modern status bar in pixels."
  :type 'integer
  :group 'modern-status-bar)

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
        (:eval " L%l:C%c")
        " %Z"
        (:eval (when (bound-and-true-p evil-mode)
                 (let ((state (symbol-name evil-state)))
                   (propertize (format " -- %s --" state)
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

(define-minor-mode modern-status-bar-mode
  "Toggle the modern status bar."
  :global t
  :lighter " MSB"
  :group 'modern-status-bar
  (if modern-status-bar-mode
      (progn
        (setq-default mode-line-format nil)
        (setq tab-bar-format '(modern-status-bar-format))
        (set-face-attribute 'tab-bar nil
                            :inherit 'modern-status-bar
                            :family (face-attribute 'modern-status-bar :family)
                            :height modern-status-bar-height
                            :foreground (face-attribute 'modern-status-bar :foreground)
                            :background (face-attribute 'modern-status-bar :background)
                            :box (face-attribute 'modern-status-bar :box))
        (tab-bar-mode 1))
    (setq-default mode-line-format (default-value 'mode-line-format))
    (setq tab-bar-format '(tab-bar-format-tabs tab-bar-format-add-tab))
    (tab-bar-mode -1))
  (force-mode-line-update t))

(provide 'modern-status-bar)
(setopt modern-status-bar-height (* (line-pixel-height) 10))
(modern-status-bar-mode 1)
