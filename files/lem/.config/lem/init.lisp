(defpackage #:arc
  (:use #:cl
        #:lem))
(in-package :arc)

;; Add local project directories
(push #P"~/common-lisp/" ql:*local-project-directories*)
(push #P"~/.config/lem/" ql:*local-project-directories*)
(ql:register-local-projects)

;; Load config system
(ql:quickload :arc)


;;(lem-core/commands/frame::maximize-frame)
;; (lem-base16-themes::define-base16-color-theme "sakurawald"
;;   :base00 "#131314" default background
;;   :base01 "#393939" status bar, line numbers and folding marks
;;   :base02 "#515151" selection
;;   :base03 "#777777" comment
;;   :base04 "#b4b7b4"
;;   :base05 "#cccccc"
;;   :base06 "#ff00ff" repl value
;;   :base07 "#ffffff" line numbers
;;   :base08 "#ff7f7b" sldb condition
;;   :base09 "#ffbf70" sldb restart
;;   :base0a "#fbf305" multiplexier
;;   :base0b "#54b33e" string
;;   :base0c "#54fcfc" keyword symbol
;;   :base0d "#4a4ffc" function name
;;   :base0e "#fc54fc" operator
;;   :base0f "#ed864a")

;;(lem-core:load-theme "sakurawald")
;; Evaluating Lisp in M-: we want to be in Lem' package.
(lem-lisp-mode/internal::lisp-set-package "LEM")
;;(lem-if:set-font-size (implementation) 14)
;;(setf (lem:variable-value 'lem-core::highlight-line-color :global) "#000066")
;;(setf lem-vi-mode/core::*default-cursor-color* "#ffffff")
(setf (lem-vi-mode:option-value "scrolloff") 5)

;;(add-hook *prompt-after-activate-hook*
;;          (lambda ()
;;            (call-command 'lem/prompt-window::prompt-completion nil)))
;;
;;(add-hook *prompt-deactivate-hook*
;;          (lambda ()
;;            (lem/completion-mode:completion-end)))

(setf lem-core::*default-prompt-gravity* :top-display)
;;(setf lem-core::*default-prompt-gravity* :display)
;;(setf lem-lisp-mode/completion:*documentation-popup-gravity* :vertically-adjacent-window)
(setf lem/prompt-window::*fill-width* nil)

