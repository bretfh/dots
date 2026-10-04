;; (setq-default mode-line-format
;;               '("%e"
;;                 vex-modeline-kbd-macro
;;                 vex-modeline-narrow
;;                 vex-modeline-input-method
;;                 vex-modeline-buffer-status
;;                 " "
;;                 vex-modeline-buffer-identification
;;                 "  "
;;                 vex-modeline-major-mode
;;                 vex-modeline-process
;;                 "  "
;;                 vex-modeline-vc-branch
;;                 "  "
;;                 vex-modeline-flymake
;;                 "  "
;;                 vex-modeline-align-right
;;                 vex-modeline-misc-info))

;(setq mode-line-format nil)
;;(kill-local-variable 'mode-line-format)
;;(force-mode-line-update)

(setq-default mode-line-format
              '("%e"
		(:eval (evil-generate-mode-line-tag evil-state))
                vex-modeline-buffer-name
		" "
		vex-modeline-buffer-status
                "  "
                vex-modeline-major-mode-right))

(defface vex-modeline-background
  '((t :inherit (underline)))
  "Face with a ... background for use on the mode line.")

(defface vex-modeline-background-inactive
  '((t :inherit default))
  "Face with a ... background for use on the mode line.")

(defun vex-modeline--buffer-name ()
  "Return `buffer-name' with spaces around it."
  (format " %s " (buffer-name)))

(defvar-local vex-modeline-buffer-name
    '(:eval
      (if (mode-line-window-selected-p)
          (propertize (vex-modeline--buffer-name) 'face 'vex-modeline-background)
	(propertize (vex-modeline--buffer-name) 'face 'vex-modeline-background-inactive)))
  "Mode line construct to display the buffer name.")

(put 'vex-modeline-buffer-name 'risky-local-variable t)

(defun vex-modeline--major-mode-name ()
  "Return capitalized `major-mode' as a string."
  (string-join (butlast (split-string (symbol-name major-mode) "-")) "-"))

(defvar-local vex-modeline-major-mode
    '(:eval
      (list
       (propertize "mode:" 'face 'shadow)
       " "
       (propertize (vex-modeline--major-mode-name) 'face 'bold)))
  "Mode line construct to display the major mode.")

(put 'vex-modeline-major-mode 'risky-local-variable t)

(defun vex-modeline--buffer-status ()
  "Return a red asterisk if the buffer has been modified."
  (if (buffer-modified-p)
      (propertize "*" 'face '(:foreground "red"))
    ""))

(defvar-local vex-modeline-buffer-status
  '(:eval (vex-modeline--buffer-status))
  "Mode line construct for buffer modification status.")

(put 'vex-modeline-buffer-status 'risky-local-variable t)

(defvar-local vex-modeline-cursor-position
  '(:eval (format "[%d:%d]  " (line-number-at-pos) (current-column)))
  "Mode line construct for cursor position (line,column).")

(put 'vex-modeline-cursor-position 'risky-local-variable t)

(defun vex-modeline--right-align ()
  "Create a string with spaces to right-align elements in the mode line."
  (let* ((right-width (string-width (format-mode-line (list vex-modeline-major-mode vex-modeline-cursor-position))))
         (available-space (- (window-total-width) right-width)))
    (propertize " " 'display `(space :align-to (- right ,right-width)))))

(defvar-local vex-modeline-major-mode-right
  '(:eval (concat (vex-modeline--right-align)
           (format-mode-line vex-modeline-major-mode)
           "  "
           (format-mode-line vex-modeline-cursor-position)))
  "Mode line construct for right-aligned major mode and cursor position.")
(put 'vex-modeline-major-mode-right 'risky-local-variable t)

;; Emacs 29, check the definition right below
(mode-line-window-selected-p)

(defun mode-line-window-selected-p ()
  "Return non-nil if we're updating the mode line for the selected window.
This function is meant to be called in `:eval' mode line
constructs to allow altering the look of the mode line depending
on whether the mode line belongs to the currently selected window
or not."
  (let ((window (selected-window)))
    (or (eq window (old-selected-window))
	(and (minibuffer-window-active-p (minibuffer-window))
	     (with-selected-window (minibuffer-window)
	       (eq window (minibuffer-selected-window)))))))

(use-package mini-echo
  :config
  (mini-echo-mode 1))

(provide 'rez-modeline)
