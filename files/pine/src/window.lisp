(in-package :pine.buffer)


;;;; ================================================================
;;;; Windows — views into buffers
;;;; ================================================================

(defclass window ()
  ((buffer-ref  :initarg :buffer  :accessor buffer-ref  :initform nil)  ; buffer actor
   (buffer-name :initarg :name    :accessor window-name :initform "")
   (row         :initarg :row     :accessor row         :initform 0)    ; position in frame (cells)
   (col         :initarg :col     :accessor col         :initform 0)
   (width       :initarg :width   :accessor win-width   :initform 80)
   (height      :initarg :height  :accessor win-height  :initform 24)
   (scroll-top  :initarg :scroll  :accessor scroll-top  :initform 0)    ; first visible line
   (focusedp    :initarg :focused :accessor focusedp    :initform nil)
   (snap        :initarg :snap    :accessor snap        :initform nil)   ; latest snapshot
   (display     :initarg :display :accessor win-display :initform nil))) ; cached display-lines

(defclass frame ()
  ((windows    :initarg :windows :accessor windows         :initform nil)
   (cols       :initarg :cols    :accessor frame-cols      :initform 80)
   (rows       :initarg :rows    :accessor frame-rows      :initform 30)
   (bg-face    :initarg :bg      :accessor bg-face         :initform :default)
   (cells      :accessor frame-cells      :initform nil)
   (cell-count :accessor frame-cell-count :initform 0)
   (cursor-row    :accessor frame-cursor-row    :initform 0)
   (cursor-col    :accessor frame-cursor-col    :initform 0)
   (scroll-pixel  :accessor frame-scroll-pixel  :initform 0.0d0)
   (dirtyp        :accessor frame-dirtyp        :initform t)))

(defun ensure-frame-cells (f)
  ;; rows + headroom: completion candidates overlay buffer rows, so more cells
  ;; may be emitted than the base grid holds.
  (let ((needed (* (frame-cols f) (+ (frame-rows f) 16) 10)))
    (when (or (null (frame-cells f))
              (< (length (frame-cells f)) needed))
      (setf (frame-cells f) (make-array needed)
            (frame-dirtyp f) t))
    (setf (frame-cell-count f) 0)))


;;;; Window management

(defun make-window (buffer-actor name &key (row 0) (col 0) (width 80) (height 24) focused)
  (let ((w (make-instance 'window
             :buffer buffer-actor :name name
             :row row :col col :width width :height height
             :focused focused))
        (cli pine.client:*client*))
    (when cli
      (push w (pine.client:windows cli))
      (when focused (setf (pine.client:focused-window cli) w)))
    w))

(defun remove-window (w)
  (let ((cli pine.client:*client*))
    (when cli
      (setf (pine.client:windows cli) (remove w (pine.client:windows cli)))
      (when (eq w (pine.client:focused-window cli))
        (setf (pine.client:focused-window cli) (first (pine.client:windows cli)))))))

(defun focus-window (w)
  (let ((cli pine.client:*client*))
    (when cli
      (let ((prev (pine.client:focused-window cli)))
        (when prev (setf (focusedp prev) nil)))
      (setf (focusedp w) t
            (pine.client:focused-window cli) w))))


;;;; Window display computation

(defun window-display-lines (w)
  "Compute display-lines for window W from its snapshot.
Clips lines to window width using horizontal scroll offset (col)."
  (let ((s (snap w)))
    (unless s (return-from window-display-lines nil))
    (let* ((ls (lines s))
           (top (scroll-top w))
           (h (win-height w))
           (wid (win-width w))
           (left (col w))
           (result nil))
      (loop for i from top below (min (+ top h 1) (fset:size ls))
            for line-text = (fset:@ ls i)
            for len = (length line-text)
            for start = (min left len)
            for end = (min (+ left wid) len)
            do (push (make-display-line (subseq line-text start end)) result))
      ;; pad remaining rows with empty lines
      (loop for i from (length result) below h
            do (push (make-display-line "") result))
      (nreverse result))))

(defun ensure-point-visible (w)
  "Scroll window W so point is visible."
  (let ((s (snap w)))
    (when s
      (let ((pl (point-line s))
            (top (scroll-top w))
            (h (win-height w)))
        (cond
          ((< pl top) (setf (scroll-top w) pl))
          ((>= pl (+ top h)) (setf (scroll-top w) (1+ (- pl h)))))))))

(defun ensure-col-visible (w)
  "Scroll window W horizontally so point column is visible."
  (let ((s (snap w)))
    (when s
      (let ((pc (point-col s))
            (left (col w))
            (wid (win-width w)))
        (cond
          ((< pc left) (setf (col w) pc))
          ((>= pc (+ left wid)) (setf (col w) (1+ (- pc wid)))))))))


;;;; Frame building

(defun build-frame (&optional (cli (pine.client:current-client)))
  (let ((f (pine.client:frame cli))
        (ws (pine.client:windows cli)))
    (dolist (w ws)
      (ensure-point-visible w)
      (setf (win-display w) (window-display-lines w)))
    (setf (windows f) ws)
    f))

(defun frame-to-plist (f)
  "Serialize frame for QML."
  (list :cols (frame-cols f)
        :rows (frame-rows f)
        :windows
        (mapcar (lambda (w)
                  (list :name (window-name w)
                        :row (row w) :col (col w)
                        :width (win-width w) :height (win-height w)
                        :focused (focusedp w)
                        :point-line (if (snap w) (- (point-line (snap w)) (scroll-top w)) 0)
                        :point-col (if (snap w) (point-col (snap w)) 0)
                        :lines (mapcar #'display-line-to-plist
                                       (or (win-display w) nil))))
                (windows f))))
