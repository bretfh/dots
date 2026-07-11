(in-package :pine.layout)

;;;; The widget engine. A widget tree is laid out in three passes over a cell
;;;; raster: MEASURE reports each node's natural size bottom-up, ARRANGE assigns
;;;; absolute rects top-down (distributing slack to expanders), and PAINT writes
;;;; styled cells into each rect. Separating the passes is what gives the box
;;;; model -- alignment, expansion, and 2D placement -- that a linear emit model
;;;; cannot. Faces cascade as a background fill plus a foreground colour; after
;;;; arrange every node has an absolute rect, so hit-testing is exact.


;;;; Nodes. The base carries the arranged rect (start/end line+col), a style
;;;; FACE, and an EXPAND weight for main-axis slack distribution.

(defclass node ()
  ((key-of  :initarg :key    :accessor key-of  :initform nil)
   (parent  :initarg :parent :accessor parent  :initform nil)
   (face    :initarg :face   :accessor face    :initform nil)
   (hint    :initarg :hint   :accessor hint    :initform nil)
   (expand  :initarg :expand :accessor expand-of :initform 0)
   (start-line :initform 0 :accessor start-line)
   (start-col  :initform 0 :accessor start-col)
   (end-line   :initform 0 :accessor end-line)
   (end-col    :initform 0 :accessor end-col)))

(defclass text-node (node)
  ((content :initarg :content :accessor content :initform "")))

(defclass separator (node)
  ((sep-char :initarg :char :accessor sep-char :initform (code-char #x2500))))

(defclass spacer (node) ())            ; flexible empty space; default expand 1

(defclass field (node)
  ((content       :initarg :content       :accessor content       :initform "")
   (prefix-length :initarg :prefix-length :accessor prefix-length :initform 0)
   (input-start-line :initform 0 :accessor input-start-line)
   (input-start-col  :initform 0 :accessor input-start-col)
   (input-end-line   :initform 0 :accessor input-end-line)
   (input-end-col    :initform 0 :accessor input-end-col)))

(defclass vstack (node)
  ((children :initarg :children :accessor children :initform nil)
   (spacing  :initarg :spacing  :accessor spacing  :initform 0)
   (align    :initarg :align    :accessor align    :initform :start)))

(defclass hstack (node)
  ((children :initarg :children :accessor children :initform nil)
   (spacing  :initarg :spacing  :accessor spacing  :initform 1)
   (align    :initarg :align    :accessor align    :initform :start)))

(defclass box (node)
  ((child    :initarg :child    :accessor child    :initform nil)
   (width-of :initarg :width    :accessor width-of :initform 0)
   (align    :initarg :align    :accessor align    :initform :left)
   (pad-char :initarg :pad      :accessor pad-char :initform #\space)))

(defclass center (node)
  ((child :initarg :child :accessor child :initform nil)))

(defclass scroll (node)
  ((child   :initarg :child  :accessor child         :initform nil)
   (offset  :initarg :offset :accessor scroll-offset :initform 0)
   (vheight :initarg :height :accessor vheight        :initform 10)))

(defclass selectable (node)
  ((child             :initarg :child    :accessor child             :initform nil)
   (data              :initarg :data     :accessor data              :initform nil)
   (selectedp         :initarg :selected :accessor selectedp         :initform nil)
   (prefix-selected   :initarg :prefix-selected   :accessor prefix-selected   :initform "> ")
   (prefix-unselected :initarg :prefix-unselected :accessor prefix-unselected :initform "  ")))

(defclass action (node)
  ((child    :initarg :child    :accessor child    :initform nil)
   (callback :initarg :callback :accessor callback :initform nil)))

(defclass list-node (node)
  ((items       :initarg :items       :accessor items       :initform nil)
   (item-fn     :initarg :item-fn     :accessor item-fn     :initform nil)
   (max-visible :initarg :max-visible :accessor max-visible :initform nil)
   ;; the item nodes built at the last measure, kept so arrange/paint and
   ;; hit-testing can reach them (item-fn builds them transiently otherwise).
   (rendered    :accessor rendered    :initform nil)))

(defclass grid (node)
  ((cells      :initarg :cells      :accessor cells      :initform nil)
   (col-widths :initarg :col-widths :accessor col-widths :initform nil)))

(defclass slider (node)
  ((value       :initarg :value       :accessor value       :initform 0)
   (min-of      :initarg :min         :accessor min-of      :initform 0)
   (max-of      :initarg :max         :accessor max-of      :initform 100)
   (track       :initarg :track       :accessor track       :initform 16)
   ;; on-change is a function of the new value; clicking/dragging at a column
   ;; maps to a value and calls it.
   (on-change   :initarg :on-change   :accessor on-change   :initform nil)
   (filled-face :initarg :filled-face :accessor filled-face :initform :function-name)
   (empty-face  :initarg :empty-face  :accessor empty-face  :initform :comment)))

(defmethod initialize-instance :after ((n spacer) &key)
  (when (zerop (expand-of n)) (setf (expand-of n) 1)))


;;;; Declarative constructor DSL. Each widget is a terse function: leading
;;;; :keyword value pairs are props, the remaining arguments are children (a
;;;; child that is itself a list is spliced, so (mapcar ...) works like eww's
;;;; `for'). Trees read like markup -- (column :spacing 1 (label "a") (row ...))
;;;; -- and defwidget names a reusable component. This is the eww analog.

(defun %parse-args (args)
  "(values plist children): peel leading keyword/value prop pairs, then treat the
rest as children, dropping nils and splicing lists."
  (let ((props nil) (rest args))
    (loop while (and rest (keywordp (car rest)) (cdr rest))
          do (push (pop rest) props) (push (pop rest) props))
    (values (nreverse props)
            (loop for c in rest when c append (if (listp c) c (list c))))))

(defun label (text &rest props)
  "A text run. (label \"hi\" :face :keyword)"
  (make-instance 'text-node :content (or text "") :face (getf props :face)))

(defun icon (glyph &rest props)
  "A glyph (a codepoint or string), optionally clickable via :on-click.
(icon #xF120 :on-click thunk :face :string)"
  (let ((lbl (make-instance 'text-node
               :content (if (integerp glyph) (string (code-char glyph)) (string glyph))
               :face (getf props :face))))
    (if (getf props :on-click)
        (make-instance 'action :callback (getf props :on-click)
                               :hint (getf props :hint) :child lbl)
        lbl)))

(defun column (&rest args)
  "A vertical box. Props :spacing :align :expand :face; rest are children."
  (multiple-value-bind (props kids) (%parse-args args)
    (apply #'make-instance 'vstack :children kids props)))

(defun row (&rest args)
  "A horizontal box. Props :spacing :align :expand :face; rest are children."
  (multiple-value-bind (props kids) (%parse-args args)
    (apply #'make-instance 'hstack :children kids props)))

(defun button (&rest args)
  "A clickable wrapper. (button :on-click thunk :hint \"...\" (label \"go\"))"
  (multiple-value-bind (props kids) (%parse-args args)
    (make-instance 'action :callback (getf props :on-click) :hint (getf props :hint)
                           :face (getf props :face) :child (first kids))))

(defun boxed (&rest args)
  "A fixed-width cell. Props :width :align :pad :face; one child."
  (multiple-value-bind (props kids) (%parse-args args)
    (apply #'make-instance 'box :child (first kids) props)))

(defun centered (&rest args)
  "Centre one child in the space it is given."
  (multiple-value-bind (props kids) (%parse-args args)
    (apply #'make-instance 'center :child (first kids) props)))

(defun viewport (&rest args)
  "A clipped, scrollable window onto a taller child. Props :height :offset."
  (multiple-value-bind (props kids) (%parse-args args)
    (apply #'make-instance 'scroll :child (first kids) props)))

(defun gap (&rest props)
  "Flexible empty space. (gap :expand 2)"
  (apply #'make-instance 'spacer props))

(defun rule (&rest props)
  "A separator line. (rule :char #\\= :face :comment)"
  (apply #'make-instance 'separator props))

(defun meter (&rest props)
  "A slider/gauge. (meter :value v :min 0 :max 100 :track 12 :on-change fn)"
  (apply #'make-instance 'slider props))

(defun rows (items item-fn &rest props)
  "A vertical list built by mapping ITEM-FN over ITEMS. (rows nets #'net-row)"
  (apply #'make-instance 'list-node :items items :item-fn item-fn props))

(defun choice (&rest args)
  "A selectable row (keyboard-navigable). (choice :data d (label ...))"
  (multiple-value-bind (props kids) (%parse-args args)
    (apply #'make-instance 'selectable :child (first kids) props)))


;;;; Faces -> cell colours

(defun %hex-rgb (hex)
  "The (values r g b) of a #rrggbb face colour, or a light default."
  (if (and hex (>= (length hex) 7) (char= (char hex 0) #\#))
      (values (parse-integer hex :start 1 :end 3 :radix 16)
              (parse-integer hex :start 3 :end 5 :radix 16)
              (parse-integer hex :start 5 :end 7 :radix 16))
      (values 205 214 244)))

(defun %face-cell-rgb (designator)
  "(values fr fg fb br bg bb bold) for a face DESIGNATOR; bg -1 means none.
Falls back to the default when no face (or no client to resolve it) exists."
  (let ((f (and designator (ignore-errors (pine.buffer:find-face designator)))))
    (if f
        (multiple-value-bind (fr fg fb) (%hex-rgb (or (pine.buffer:fg f) "#cdd6f4"))
          (if (pine.buffer:bg f)
              (multiple-value-bind (br bg bb) (%hex-rgb (pine.buffer:bg f))
                (values fr fg fb br bg bb (if (pine.buffer:bold f) 1 0)))
              (values fr fg fb -1 -1 -1 (if (pine.buffer:bold f) 1 0))))
        (values 205 214 244 -1 -1 -1 0))))


;;;; Raster — a cell buffer widgets paint into. Cells are the flat 10-slot
;;;; [row col code fr fg fb br bg bb bold] format the surface painter draws.

(defstruct (raster (:constructor %make-raster)) cols rows cells (clip nil))

(defun make-raster (cols rows)
  (let* ((n (* cols rows)) (v (make-array (* 10 n))))
    (dotimes (i n)
      (let ((off (* 10 i)))
        (setf (svref v off) (floor i cols)
              (svref v (+ off 1)) (mod i cols)
              (svref v (+ off 2)) 32
              (svref v (+ off 3)) 205 (svref v (+ off 4)) 214 (svref v (+ off 5)) 244
              (svref v (+ off 6)) -1 (svref v (+ off 7)) -1 (svref v (+ off 8)) -1
              (svref v (+ off 9)) 0)))
    (%make-raster :cols cols :rows rows :cells v)))

(declaim (inline %cell-off %in-raster))
(defun %cell-off (r row col) (* 10 (+ (* row (raster-cols r)) col)))
(defun %in-raster (r row col)
  (and (>= row 0) (< row (raster-rows r)) (>= col 0) (< col (raster-cols r))
       (let ((c (raster-clip r)))
         (or (null c)
             (and (>= col (first c)) (< col (third c))
                  (>= row (second c)) (< row (fourth c)))))))

(defmacro %with-clip ((r x0 y0 x1 y1) &body body)
  "Restrict raster writes to the rect [X0 X1) x [Y0 Y1) within BODY."
  (let ((rr (gensym)) (old (gensym)))
    `(let* ((,rr ,r) (,old (raster-clip ,rr)))
       (setf (raster-clip ,rr) (list ,x0 ,y0 ,x1 ,y1))
       (unwind-protect (progn ,@body) (setf (raster-clip ,rr) ,old)))))

(defun raster-put (r row col ch face)
  (when (%in-raster r row col)
    (multiple-value-bind (fr fg fb br bg bb bold) (%face-cell-rgb face)
      (let ((off (%cell-off r row col)) (v (raster-cells r)))
        (setf (svref v (+ off 2)) (char-code ch)
              (svref v (+ off 3)) fr (svref v (+ off 4)) fg (svref v (+ off 5)) fb
              (svref v (+ off 9)) bold)
        (when (>= br 0)
          (setf (svref v (+ off 6)) br (svref v (+ off 7)) bg (svref v (+ off 8)) bb))))))

(defun raster-put-bg (r row col br bg bb)
  (when (%in-raster r row col)
    (let ((off (%cell-off r row col)) (v (raster-cells r)))
      (setf (svref v (+ off 6)) br (svref v (+ off 7)) bg (svref v (+ off 8)) bb))))

(defun raster-lines (r)
  (loop for row from 0 below (raster-rows r)
        collect (let ((s (make-string (raster-cols r))))
                  (dotimes (col (raster-cols r))
                    (setf (char s col)
                          (code-char (svref (raster-cells r) (+ 2 (%cell-off r row col))))))
                  (string-right-trim '(#\space) s))))


;;;; Layout protocol

(defgeneric measure (node avail-w avail-h)
  (:documentation "The node's natural (values w h) in cells given the available
space. Bottom-up; does not set bounds."))

(defgeneric arrange (node x y w h)
  (:documentation "Assign the node the rect X Y W H and place its children."))

(defgeneric paint (node raster)
  (:documentation "Draw the node into its arranged rect on RASTER."))

(defun %node-width (n) (- (end-col n) (start-col n)))

(defmethod measure ((n node) aw ah) (declare (ignore aw ah)) (values 0 1))

(defmethod arrange ((n node) x y w h)
  (setf (start-col n) x (start-line n) y
        (end-col n) (+ x w) (end-line n) (+ y (max 0 (1- h)))))

(defmethod paint ((n node) r) (declare (ignore r)) nil)

(defun %fill-bg (n r)
  "Fill the node's rect background if its face carries one."
  (let ((f (face n)))
    (when f
      (multiple-value-bind (fr fg fb br bg bb bold) (%face-cell-rgb f)
        (declare (ignore fr fg fb bold))
        (when (>= br 0)
          (loop for row from (start-line n) to (end-line n) do
            (loop for col from (start-col n) below (end-col n)
                  do (raster-put-bg r row col br bg bb))))))))

(defmethod paint :before ((n node) r) (%fill-bg n r))

;;; Leaves

(defmethod measure ((n text-node) aw ah)
  (declare (ignore aw ah)) (values (length (content n)) 1))
(defmethod paint ((n text-node) r)
  (let ((s (content n)) (w (%node-width n)))
    (loop for i from 0 below (min (length s) w)
          do (raster-put r (start-line n) (+ (start-col n) i) (char s i) (face n)))))

(defmethod measure ((n separator) aw ah) (declare (ignore ah)) (values aw 1))
(defmethod paint ((n separator) r)
  (loop for col from (start-col n) below (end-col n)
        do (raster-put r (start-line n) col (sep-char n) (face n))))

(defmethod measure ((n spacer) aw ah) (declare (ignore aw ah)) (values 0 0))

(defmethod measure ((n field) aw ah)
  (declare (ignore aw ah)) (values (length (content n)) 1))
(defmethod arrange ((n field) x y w h)
  (call-next-method)
  (setf (input-start-line n) y (input-start-col n) (+ x (prefix-length n))
        (input-end-line n) y (input-end-col n) (+ x (length (content n)))))
(defmethod paint ((n field) r)
  (let ((s (content n)) (w (%node-width n)))
    (loop for i from 0 below (min (length s) w)
          do (raster-put r (start-line n) (+ (start-col n) i) (char s i) (face n)))))

(defparameter +slider-filled+ (code-char #x2588)) ; full block
(defparameter +slider-empty+  (code-char #x2500)) ; light horizontal

(defmethod measure ((n slider) aw ah) (declare (ignore aw ah)) (values (track n) 1))
(defmethod paint ((n slider) r)
  (let* ((w (track n))
         (span (max 1 (- (max-of n) (min-of n))))
         (v (max 0 (min span (- (value n) (min-of n)))))
         (fill (round (* (/ v span) w))))
    (loop for i from 0 below w
          do (raster-put r (start-line n) (+ (start-col n) i)
                         (if (< i fill) +slider-filled+ +slider-empty+)
                         (if (< i fill) (filled-face n) (empty-face n))))))

(defun slider-value-at (n col)
  "The value a click at absolute COL maps to for arranged slider N."
  (let* ((rel (max 0 (min (track n) (- col (start-col n)))))
         (span (- (max-of n) (min-of n))))
    (+ (min-of n) (round (* (/ rel (track n)) span)))))

;;; Containers — the flex box algebra

(defmethod measure ((n vstack) aw ah)
  (let ((w 0) (h 0) (kids (children n)))
    (dolist (c kids)
      (multiple-value-bind (cw ch) (measure c aw ah)
        (setf w (max w cw)) (incf h ch)))
    (values w (+ h (* (spacing n) (max 0 (1- (length kids))))))))

(defmethod arrange ((n vstack) x y w h)
  (call-next-method)
  (let* ((kids (children n))
         (nats (mapcar (lambda (c) (multiple-value-list (measure c w h))) kids))
         (natsum (+ (reduce #'+ (mapcar #'second nats) :initial-value 0)
                    (* (spacing n) (max 0 (1- (length kids))))))
         (slack (max 0 (- h natsum)))
         (tw (reduce #'+ (mapcar #'expand-of kids) :initial-value 0))
         (cy y))
    (loop for c in kids for (cw ch) in nats
          for extra = (if (plusp tw) (round (* slack (/ (expand-of c) tw))) 0)
          for fh = (+ ch extra)
          for cx = (ecase (align n)
                     ((:start :stretch) x)
                     (:center (+ x (floor (- w cw) 2)))
                     (:end (+ x (- w cw))))
          for fw = (if (eq (align n) :stretch) w cw)
          do (arrange c cx cy fw fh)
             (setf cy (+ cy fh (spacing n))))))

(defmethod paint ((n vstack) r) (dolist (c (children n)) (paint c r)))

(defmethod measure ((n hstack) aw ah)
  (let ((w 0) (h 0) (kids (children n)))
    (dolist (c kids)
      (multiple-value-bind (cw ch) (measure c aw ah)
        (incf w cw) (setf h (max h ch))))
    (values (+ w (* (spacing n) (max 0 (1- (length kids))))) h)))

(defmethod arrange ((n hstack) x y w h)
  (call-next-method)
  (let* ((kids (children n))
         (nats (mapcar (lambda (c) (multiple-value-list (measure c w h))) kids))
         (natsum (+ (reduce #'+ (mapcar #'first nats) :initial-value 0)
                    (* (spacing n) (max 0 (1- (length kids))))))
         (slack (max 0 (- w natsum)))
         (tw (reduce #'+ (mapcar #'expand-of kids) :initial-value 0))
         (cx x))
    (loop for c in kids for (cw ch) in nats
          for extra = (if (plusp tw) (round (* slack (/ (expand-of c) tw))) 0)
          for fw = (+ cw extra)
          for cy = (ecase (align n)
                     ((:start :stretch) y)
                     (:center (+ y (floor (- h ch) 2)))
                     (:end (+ y (- h ch))))
          for fh = (if (eq (align n) :stretch) h ch)
          do (arrange c cx cy fw fh)
             (setf cx (+ cx fw (spacing n))))))

(defmethod paint ((n hstack) r) (dolist (c (children n)) (paint c r)))

(defmethod measure ((n box) aw ah)
  (declare (ignore aw))
  (let ((c (child n)))
    (values (width-of n) (if c (nth-value 1 (measure c (width-of n) ah)) 1))))
(defmethod arrange ((n box) x y w h)
  (declare (ignore w))
  (call-next-method n x y (width-of n) h)
  (let ((c (child n)))
    (when c
      (multiple-value-bind (cw ch) (measure c (width-of n) h)
        (let ((cx (ecase (align n)
                    (:left x)
                    (:right (+ x (- (width-of n) cw)))
                    (:center (+ x (floor (- (width-of n) cw) 2))))))
          (arrange c cx y cw (max 1 ch)))))))
(defmethod paint ((n box) r)
  (unless (char= (pad-char n) #\space)
    (loop for col from (start-col n) below (end-col n)
          do (raster-put r (start-line n) col (pad-char n) (face n))))
  (when (child n) (paint (child n) r)))

(defmethod measure ((n center) aw ah)
  (if (child n) (measure (child n) aw ah) (values 0 0)))
(defmethod arrange ((n center) x y w h)
  (call-next-method)
  (let ((c (child n)))
    (when c
      (multiple-value-bind (cw ch) (measure c w h)
        (arrange c (+ x (floor (- w cw) 2)) (+ y (floor (- h ch) 2)) cw ch)))))
(defmethod paint ((n center) r) (when (child n) (paint (child n) r)))

(defmethod measure ((n scroll) aw ah)
  (declare (ignore ah))
  (values (if (child n) (nth-value 0 (measure (child n) aw 100000)) 0)
          (vheight n)))
(defmethod arrange ((n scroll) x y w h)
  (call-next-method n x y w (vheight n))
  (when (child n)
    (let ((ch (nth-value 1 (measure (child n) w 100000))))
      ;; the child is laid out at full height, shifted up by the scroll offset;
      ;; paint clips it to the viewport.
      (arrange (child n) x (- y (scroll-offset n)) w ch))))
(defmethod paint ((n scroll) r)
  (when (child n)
    (%with-clip (r (start-col n) (start-line n) (end-col n) (+ (start-line n) (vheight n)))
      (paint (child n) r))))

(defmethod measure ((n selectable) aw ah)
  (let ((pfx (if (selectedp n) (prefix-selected n) (prefix-unselected n))))
    (multiple-value-bind (cw ch) (if (child n) (measure (child n) aw ah) (values 0 1))
      (values (+ (length pfx) cw) ch))))
(defmethod arrange ((n selectable) x y w h)
  (call-next-method)
  (let ((pfx (if (selectedp n) (prefix-selected n) (prefix-unselected n))))
    (when (child n) (arrange (child n) (+ x (length pfx)) y (- w (length pfx)) h))))
(defmethod paint ((n selectable) r)
  (let ((pfx (if (selectedp n) (prefix-selected n) (prefix-unselected n))))
    (loop for i from 0 below (length pfx)
          do (raster-put r (start-line n) (+ (start-col n) i) (char pfx i) (face n)))
    (when (child n) (paint (child n) r))))

(defmethod measure ((n action) aw ah)
  (if (child n) (measure (child n) aw ah) (values 0 1)))
(defmethod arrange ((n action) x y w h)
  (call-next-method)
  (when (child n) (arrange (child n) x y w h)))
(defmethod paint ((n action) r) (when (child n) (paint (child n) r)))

(defun %list-kids (n)
  (let* ((is (items n)) (mx (max-visible n))
         (vis (if mx (subseq is 0 (min mx (length is))) is)))
    (setf (rendered n)
          (loop for item in vis for i from 0 collect (funcall (item-fn n) item i)))))

(defmethod measure ((n list-node) aw ah)
  (let ((w 0) (h 0))
    (dolist (c (%list-kids n))
      (multiple-value-bind (cw ch) (measure c aw ah) (setf w (max w cw)) (incf h ch)))
    (values w h)))
(defmethod arrange ((n list-node) x y w h)
  (call-next-method)
  (let ((cy y))
    (dolist (c (rendered n))
      (let ((ch (nth-value 1 (measure c w h))))
        (arrange c x cy w ch)
        (setf cy (+ cy ch))))))
(defmethod paint ((n list-node) r) (dolist (c (rendered n)) (paint c r)))

(defmethod measure ((n grid) aw ah)
  (declare (ignore aw ah))
  (values (reduce #'+ (col-widths n) :initial-value 0) (length (cells n))))
(defmethod arrange ((n grid) x y w h)
  (call-next-method)
  (loop for row in (cells n) for ry from y do
    (loop with cx = x for cell in row for cwidth in (col-widths n)
          do (arrange cell cx ry cwidth 1) (incf cx cwidth))))
(defmethod paint ((n grid) r)
  (dolist (row (cells n)) (dolist (cell row) (paint cell r))))


;;;; Render entry points

(defun render-layout-grid (layout)
  "Render LAYOUT to (values lines cell-vector slot-count). CELL-VECTOR is the
flat 10-slot format the surface painter draws; SLOT-COUNT is 10 * cols * rows,
matching frame-cell-count so paint-cell-grid iterates it with `below n by 10'."
  (let* ((root (layout-root layout))
         (w (layout-width layout)))
    (if (null root)
        (values (list "") (make-array 0) 0)
        (multiple-value-bind (mw mh) (measure root w (or (layout-height layout) 1000))
          (declare (ignore mw))
          (let* ((h (max 1 (or (layout-height layout) mh)))
                 (r (make-raster w h)))
            (arrange root 0 0 w h)
            (paint root r)
            (values (raster-lines r) (raster-cells r) (* 10 w h)))))))

(defun render-layout (layout)
  (nth-value 0 (render-layout-grid layout)))

(defun layout-lines (layout)
  (reduce (lambda (seq line) (fset:with-last seq line))
          (render-layout layout)
          :initial-value (fset:empty-seq)))

(defun node-to-string (n width)
  "Render node N at WIDTH to a single string."
  (multiple-value-bind (mw mh) (measure n width 1)
    (declare (ignore mw mh))
    (let ((r (make-raster width 1)))
      (arrange n 0 0 width 1)
      (paint n r)
      (first (raster-lines r)))))


;;;; Widgets — a widget is a function of its arguments returning a node tree.
;;;; Reading reactive cells (pine.cell:cell-ref) in the body makes it re-render
;;;; when those cells change, when rendered inside a reactive view. Widgets
;;;; compose by calling one another.

(defmacro defwidget (name (&rest args) &body body)
  `(defun ,name (,@args) ,@body))


;;;; Scroll helper

(defun scroll-to-selection (sel offset max-vis)
  (when (minusp sel)
    (return-from scroll-to-selection (max 0 offset)))
  (let ((o offset))
    (when (>= sel (+ o max-vis)) (setf o (1+ (- sel max-vis))))
    (when (< sel o)              (setf o sel))
    (max 0 o)))


;;;; Layout container + registry (keyed by buffer name on the server)

(defclass layout ()
  ((root        :initarg :root   :accessor layout-root        :initform nil)
   (buffer-name :initarg :buffer :accessor layout-buffer-name :initform nil)
   (state       :initarg :state  :accessor layout-state       :initform nil)
   (width       :initarg :width  :accessor layout-width       :initform 80)
   ;; when set, the root is arranged into this many rows (a fixed-size surface
   ;; like the sidebar), so expanders distribute the extra space; otherwise the
   ;; natural height is used.
   (height      :initarg :height :accessor layout-height       :initform nil)))

(defun layouts-table ()
  (let ((srv (pine.client:server-of (pine.client:current-client))))
    (or (pine.server:layouts srv)
        (setf (pine.server:layouts srv) (make-hash-table :test #'equal)))))

(defun install-layout (layout)
  (setf (gethash (layout-buffer-name layout) (layouts-table)) layout))

(defun uninstall-layout (layout)
  (remhash (layout-buffer-name layout) (layouts-table)))

(defun buffer-layout (name)
  (gethash name (layouts-table)))

(defun layout-get (layout key &optional default)
  (getf (layout-state layout) key default))

(defun (setf layout-get) (value layout key)
  (setf (getf (layout-state layout) key) value)
  value)


;;;; Input string operations (for fields / completing-read)

(defun input-string (layout)
  (getf (layout-state layout) :input ""))

(defun (setf input-string) (val layout)
  (setf (getf (layout-state layout) :input) val))

(defun cursor-offset (layout)
  (let ((input (input-string layout)))
    (min (getf (layout-state layout) :cursor-offset (length input))
         (length input))))

(defun (setf cursor-offset) (val layout)
  (setf (getf (layout-state layout) :cursor-offset) val))

(defun type-char-at-cursor (layout char)
  (let* ((input (input-string layout))
         (off (cursor-offset layout)))
    (setf (input-string layout)
          (concatenate 'string (subseq input 0 off) (string char) (subseq input off)))
    (setf (cursor-offset layout) (1+ off))))

(defun delete-char-before-cursor (layout)
  (let* ((input (input-string layout))
         (off (cursor-offset layout)))
    (when (plusp off)
      (setf (input-string layout)
            (concatenate 'string (subseq input 0 (1- off)) (subseq input off)))
      (setf (cursor-offset layout) (1- off))
      t)))

(defun kill-input (layout)
  (setf (input-string layout) ""
        (cursor-offset layout) 0))

(defun kill-to-end (layout)
  (let ((off (cursor-offset layout)))
    (setf (input-string layout) (subseq (input-string layout) 0 off))))

(defun find-word-start (input offset &optional (sep #\space))
  (let* ((pos (loop for i from (1- offset) downto 0
                    while (eql (char input i) sep)
                    finally (return (1+ i)))))
    (loop for i from (1- pos) downto 0
          while (not (eql (char input i) sep))
          finally (return (1+ i)))))

(defun kill-word-before-cursor (layout &optional (sep #\space))
  (let* ((input (input-string layout))
         (off (cursor-offset layout))
         (ws (find-word-start input off sep)))
    (setf (input-string layout)
          (concatenate 'string (subseq input 0 ws) (subseq input off)))
    (setf (cursor-offset layout) ws)))

(defun set-input (layout text)
  (setf (input-string layout) (or text "")
        (cursor-offset layout) (length (or text ""))))

(defun move-cursor (layout delta)
  (let* ((input (input-string layout))
         (off (cursor-offset layout))
         (new (max 0 (min (length input) (+ off delta)))))
    (setf (cursor-offset layout) new)))

(defun cursor-to-start (layout)
  (setf (cursor-offset layout) 0))

(defun cursor-to-end (layout)
  (setf (cursor-offset layout) (length (input-string layout))))

(defun confirm-input (layout)
  (let ((sel (getf (layout-state layout) :selection -1))
        (filtered (getf (layout-state layout) :filtered)))
    (if (and (>= sel 0) (< sel (length filtered)))
        (nth sel filtered)
      (input-string layout))))


;;;; Hit-testing — map an arranged (line col) to the node under it.

(defun %node-contains (n line col)
  (and (<= (start-line n) line (end-line n))
       (cond ((= (start-line n) (end-line n))
              (and (<= (start-col n) col) (< col (end-col n))))
             ((= line (start-line n)) (<= (start-col n) col))
             ((= line (end-line n))   (< col (end-col n)))
             (t t))))

(defun node-at (node line col)
  "The deepest action, selectable, or slider whose rect contains (LINE COL)."
  (labels ((walk (n)
             (when n
               (typecase n
                 (action     (when (%node-contains n line col) (or (walk (child n)) n)))
                 (selectable (when (%node-contains n line col) (or (walk (child n)) n)))
                 (slider     (when (%node-contains n line col) n))
                 (hstack (some #'walk (children n)))
                 (vstack (some #'walk (children n)))
                 (box    (walk (child n)))
                 (center (walk (child n)))
                 (scroll (when (%node-contains n line col) (walk (child n))))
                 (grid   (some (lambda (row) (some #'walk row)) (cells n)))
                 (list-node (some #'walk (rendered n)))
                 (t nil)))))
    (walk node)))

(defun action-at (node line col)
  "The callback of the action under (LINE COL), or nil."
  (let ((hit (node-at node line col)))
    (when (typep hit 'action) (callback hit))))

(defun hint-at (root line col)
  "The hover hint of the node under (LINE COL), or nil."
  (let ((n (node-at root line col)))
    (and n (hint n))))

(defun click-thunk (root line col)
  "A nullary thunk for a click at (LINE COL) on arranged ROOT: an action's
callback, or a slider's on-change applied to the column-mapped value. Nil if the
point is over neither."
  (let ((hit (node-at root line col)))
    (typecase hit
      (action (callback hit))
      (slider (let ((fn (on-change hit)) (v (slider-value-at hit col)))
                (when fn (lambda () (funcall fn v)))))
      (t nil))))


;;;; Selection navigation

(defun collect-selectables (n)
  (let ((result nil))
    (labels ((walk (x)
               (when x
                 (typecase x
                   (selectable (push x result))
                   (vstack (mapc #'walk (children x)))
                   (hstack (mapc #'walk (children x)))
                   (box (walk (child x)))
                   (center (walk (child x)))
                   (scroll (walk (child x)))
                   (grid (dolist (row (cells x)) (mapc #'walk row)))
                   (action (walk (child x)))
                   (list-node (mapc #'walk (rendered x)))
                   (t nil)))))
      (walk n))
    (nreverse result)))

(defun update-selection (layout index)
  (let* ((sels (collect-selectables (layout-root layout)))
         (n (length sels)))
    (when (zerop n) (return-from update-selection nil))
    (setf index (mod index n))
    (setf (layout-get layout :selection-index) index)
    (loop for s in sels for i from 0
          do (setf (selectedp s) (= i index)))
    (nth index sels)))

(defun selected-node (layout)
  (let ((idx (layout-get layout :selection-index 0)))
    (let ((sels (collect-selectables (layout-root layout))))
      (when sels (nth (mod idx (length sels)) sels)))))

(defun selection-move (layout delta)
  (let ((idx (layout-get layout :selection-index 0)))
    (update-selection layout (+ idx delta))))
