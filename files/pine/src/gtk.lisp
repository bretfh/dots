(defpackage #:pine.gtk
  (:use #:cl #:gtk4 #:pine.surface)
  (:export #:gtk-surface #:run))

(in-package #:pine.gtk)

(defvar *surface* nil)
(defvar *client* nil)

(defclass gtk-surface (surface)
  ((window :accessor gs-window :initform nil)
   (area   :accessor gs-area   :initform nil)
   (frame  :accessor gs-frame  :initform nil)
   (cell-w :accessor gs-cell-w :initform 9d0)
   (cell-h :accessor gs-cell-h :initform 18d0)
   (ascent :accessor gs-ascent :initform 14d0)
   (font   :accessor gs-font   :initform 15d0)
   ;; cell metrics are measured from the font on first paint, not guessed.
   (measured :accessor gs-measured :initform nil)
   ;; last allocated pixel size, updated from the draw callback.
   (width  :accessor gs-width  :initform 800)
   (height :accessor gs-height :initform 500)))

(defun measure-font (s)
  "Set cell width/height/ascent from the current cairo font. Call with a live
cairo context and the font face/size already selected."
  (multiple-value-bind (xb yb w h xadv) (cairo:text-extents "MMMMMMMMMM")
    (declare (ignore xb yb w h))
    (when (plusp xadv) (setf (gs-cell-w s) (/ xadv 10d0))))
  (let ((fe (cairo:get-font-extents)))
    (setf (gs-cell-h s) (cairo:font-height fe)
          (gs-ascent s) (cairo:font-ascent fe)))
  (setf (gs-measured s) t))

(defmethod surface-metrics ((s gtk-surface))
  (values (gs-cell-w s) (gs-cell-h s)
          (max 1 (floor (gs-width s) (gs-cell-w s)))
          (max 1 (floor (gs-height s) (gs-cell-h s)))))

(defmethod paint-frame ((s gtk-surface) frame)
  (setf (gs-frame s) frame)
  (request-redraw s))

(defmethod request-redraw ((s gtk-surface))
  (let ((area (gs-area s)))
    (when area
      (run-in-main-event-loop () (widget-queue-draw area)))))

(defun paint-cells (s)
  (cairo:set-source-rgb 0.12d0 0.12d0 0.14d0)
  (cairo:paint)
  (cairo:select-font-face *font-family* :normal :normal)
  (cairo:set-font-size (gs-font s))
  (unless (gs-measured s) (measure-font s))
  (let ((frame (gs-frame s)))
    (when frame
      (let ((cells (pine.buffer:frame-cells frame))
            (n (pine.buffer:frame-cell-count frame))
            (cw (gs-cell-w s)) (lh (gs-cell-h s)) (asc (gs-ascent s)) (x0 6d0))
        ;; background fills first (modeline bar, completion rows), then glyphs.
        (paint-cell-grid cells n cw lh asc x0)
        (cairo:set-source-rgb 0.50d0 0.70d0 0.90d0)
        (cairo:rectangle (+ x0 (* (pine.buffer:frame-cursor-col frame) cw))
                         (* (pine.buffer:frame-cursor-row frame) lh) cw lh)
        (cairo:set-line-width 1.5d0)
        (cairo:stroke)))))

(cffi:defcallback %draw :void ((area :pointer) (cr :pointer)
                               (width :int) (height :int) (data :pointer))
  (declare (ignore area data))
  (when *surface*
    (setf (gs-width *surface*) width
          (gs-height *surface*) height)
    (let ((cairo:*context* (make-instance 'cairo:context :pointer cr
                                          :width width :height height
                                          :pixel-based-p nil)))
      (paint-cells *surface*))))

(defun sync-size (cli s)
  "Match the frame's cols/rows to the drawing area's current pixel size."
  (multiple-value-bind (cw ch cols rows) (surface-metrics s)
    (declare (ignore cw ch))
    (let ((f (pine.client:frame cli)))
      (when (or (/= cols (pine.buffer:frame-cols f))
                (/= rows (pine.buffer:frame-rows f)))
        (setf (pine.buffer:frame-cols f) cols
              (pine.buffer:frame-rows f) rows)
        (pine.render:relayout)
        (pine.buffer:ensure-frame-cells f)
        (let ((rs (pine.client:render-state cli)))
          (setf (pine.client:render-state cli) (fset:with rs :dirty t)))))))

(defun pump (cli s)
  (let ((pine.client:*client* cli))
    (sync-size cli s)
    (when (pine.term:drain-terminals cli)
      (let ((rs (pine.client:render-state cli)))
        (setf (pine.client:render-state cli) (fset:with rs :dirty t))))
    (let ((rs (pine.client:render-state cli))
          (w (pine.client:focused-window cli)))
      (when (and w (fset:@ rs :dirty))
        (setf (pine.client:render-state cli) (fset:with rs :dirty nil))
        ;; text buffers need scroll/display prep; terminals render from their
        ;; own grid and have no snapshot.
        (when (pine.buffer:snap w)
          (pine.buffer:ensure-point-visible w)
          (pine.buffer:ensure-col-visible w)
          (setf (pine.buffer:win-display w) (pine.buffer:window-display-lines w)))
        ;; never let a render error take down the whole application
        (handler-case
            (progn (pine.render:render-buffer-to-frame w)
                   (paint-frame s (pine.client:frame cli)))
          (error (c)
            (pine.echo:message (format nil "render error: ~a" c))))))))

(defun gdk->key (keyval state)
  (let* ((ctrl  (logtest state gdk4:+modifier-type-control-mask+))
         (meta  (logtest state gdk4:+modifier-type-alt-mask+))
         (super (logtest state gdk4:+modifier-type-super-mask+))
         (uni   (gdk4:keyval-to-unicode keyval))
         ;; a printable key resolves to its character so C-/ C-? M-< all match
         ;; their string bindings; the char already encodes shift, so drop it.
         ;; ctrl+space stays symbolic ("space") so C-space keeps working.
         (printable (and (plusp uni) (not super)
                         (graphic-char-p (code-char uni))
                         (not (and ctrl (char= (code-char uni) #\Space))))))
    (if printable
        (pine.key:make-key (string (code-char uni)) :ctrl ctrl :meta meta :super super)
        (pine.key:make-key (gdk4:keyval-name keyval)
                           :ctrl ctrl :meta meta
                           :shift (logtest state gdk4:+modifier-type-shift-mask+)
                           :super super))))

(define-application (:name %app :id "org.pine.editor")
  (define-main-window (window (make-application-window :application *application*))
    (setf (window-title window) "pine")
    (let ((area (make-drawing-area))
          (s *surface*)
          (cli *client*))
      (setf (drawing-area-content-width area) 800
            (drawing-area-content-height area) 500
            (drawing-area-draw-func area) (list (cffi:callback %draw)
                                                (cffi:null-pointer)
                                                (cffi:null-pointer)))
      (setf (gs-area s) area
            (gs-window s) window
            (window-child window) area)
      (let ((kc (make-event-controller-key)))
        (connect kc "key-pressed"
                 (lambda (c keyval keycode state)
                   (declare (ignore c keycode))
                   (when *client*
                     (pine.command:dispatch *client* (gdk->key keyval state))
                     ;; a keypress may change only the echo area / minibuffer
                     ;; (no buffer snapshot), so force a repaint every time.
                     (let ((rs (pine.client:render-state *client*)))
                       (setf (pine.client:render-state *client*)
                             (fset:with rs :dirty t))))
                   t))
        (widget-add-controller window kc))
      (let ((f (pine.client:frame cli)))
        (setf (pine.buffer:frame-cols f) 80
              (pine.buffer:frame-rows f) 29)
        (pine.render:relayout)
        (pine.buffer:ensure-frame-cells f))
      (timeout-add 16 (lambda () (pump cli s) t))
      (window-present window)
      ;; the desktop bar is a second surface on the same substrate; a
      ;; layer-shell failure must not take the editor down.
      (when pine.de:*bar-enabled*
        (handler-case (pine.de:make-bar *application* cli)
          (error (c) (format *error-output* "pine bar failed: ~a~%" c)))))))

(defun run ()
  (multiple-value-bind (srv cli) (pine:main)
    (declare (ignore srv))
    (setf *surface* (make-instance 'gtk-surface)
          *client* cli)
    (%app)))
