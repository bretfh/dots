(defpackage #:pine.surface
  (:use #:cl)
  (:export #:surface #:surface-on-key #:surface-on-resize
           #:present #:paint-frame #:request-redraw #:surface-metrics
           #:paint-cell-grid #:*font-family*))

(in-package #:pine.surface)

(defparameter *font-family* "Maple Mono NF"
  "The cairo font family the editor and desktop surfaces render with. Must be a
monospace nerd font for the glyphs to resolve; a plain \"monospace\" lacks them.
This is the font knob.")

(defun paint-cell-grid (cells n cell-w cell-h ascent x0)
  "Paint a flat 10-slot cell grid [row col code fr fg fb br bg bb bold] with the
current cairo context and already-selected font: backgrounds first (bg -1 =
none), then glyphs. Shared by the editor and the desktop surfaces."
  (loop for i from 0 below n by 10
        for br = (svref cells (+ i 6))
        when (and (integerp br) (>= br 0))
          do (cairo:set-source-rgb (/ br 255d0)
                                   (/ (svref cells (+ i 7)) 255d0)
                                   (/ (svref cells (+ i 8)) 255d0))
             (cairo:rectangle (+ x0 (* (svref cells (+ i 1)) cell-w))
                              (* (svref cells i) cell-h) cell-w cell-h)
             (cairo:fill-path))
  (loop for i from 0 below n by 10
        do (cairo:set-source-rgb (/ (svref cells (+ i 3)) 255d0)
                                 (/ (svref cells (+ i 4)) 255d0)
                                 (/ (svref cells (+ i 5)) 255d0))
           (cairo:move-to (+ x0 (* (svref cells (+ i 1)) cell-w))
                          (+ (* (svref cells i) cell-h) ascent))
           (cairo:show-text (string (code-char (svref cells (+ i 2)))))))

(defclass surface ()
  ((on-key    :initarg :on-key    :accessor surface-on-key    :initform nil)
   (on-resize :initarg :on-resize :accessor surface-on-resize :initform nil)))

(defgeneric present (surface))
(defgeneric paint-frame (surface frame))
(defgeneric request-redraw (surface))
(defgeneric surface-metrics (surface)
  (:documentation "Values: cell-width cell-height cols rows."))
