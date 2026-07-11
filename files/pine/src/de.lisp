(defpackage #:pine.de
  (:use #:cl #:gtk4)
  (:shadowing-import-from #:pine.layout
                #:defwidget #:column #:row #:label #:icon #:button #:boxed
                #:centered #:viewport #:gap #:rule #:meter #:rows #:choice)
  (:export #:make-bar #:*bar-enabled*))

(in-package #:pine.de)

(defvar *bar-enabled* t)
(defvar *bar-client* nil)

;;;; gtk4-layer-shell — hand-bound. Turns a GtkWindow into an anchored desktop
;;;; surface. It must be loaded (LD_PRELOAD) before GTK inits its Wayland
;;;; backend or these calls are silent no-ops (see the make dev target).

(cffi:define-foreign-library libgtk4-layer-shell
  (t (:default "libgtk4-layer-shell")))

(defvar *ls-loaded* nil)
(defun ensure-layer-shell ()
  (unless *ls-loaded*
    (cffi:load-foreign-library 'libgtk4-layer-shell)
    (setf *ls-loaded* t)))

(cffi:defcfun ("gtk_layer_init_for_window" %init) :void (window :pointer))
(cffi:defcfun ("gtk_layer_set_layer" %set-layer) :void (window :pointer) (layer :int))
(cffi:defcfun ("gtk_layer_set_anchor" %set-anchor) :void
  (window :pointer) (edge :int) (anchor :boolean))
(cffi:defcfun ("gtk_layer_auto_exclusive_zone_enable" %auto-zone) :void (window :pointer))
(cffi:defcfun ("gtk_layer_set_namespace" %set-namespace) :void
  (window :pointer) (namespace :string))

;; layer: 0 background 1 bottom 2 top 3 overlay.  edge: 0 left 1 right 2 top 3 bottom.
(defun configure-bar (window)
  (ensure-layer-shell)
  (let ((p (gobject-introspection-wrapper:object-pointer window)))
    (%init p)
    (%set-namespace p "pine-bar")
    (%set-layer p 2)
    (%set-anchor p 0 t)   ; left
    (%set-anchor p 2 t)   ; top
    (%set-anchor p 3 t)   ; bottom  -> a full-height strip on the left edge
    (%auto-zone p)))


;;;; The bar is a reactive-view: its thunk builds a pine.layout tree that reads
;;;; cells (fed by pine.source), so a cell change re-renders it. Widget clicks
;;;; are in-process closures (pine.layout:action), hit-tested by column -- no
;;;; nREPL, no eww-update string protocol.

(defun %cell (name default)
  (let ((c (pine.cell:find-cell name))) (if c (pine.cell:cell-ref c) default)))

(defun %sh (cmd)
  "A thunk that runs shell CMD off the UI thread (safe from a click handler)."
  (lambda () (ignore-errors (uiop:launch-program (list "sh" "-c" cmd)))))

(defun %toggle (name)
  "A thunk that toggles panel NAME on the UI thread."
  (lambda () (run-in-main-event-loop () (toggle-panel name))))

(defun %set-volume (v)
  (ignore-errors
    (uiop:launch-program
     (list "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" (format nil "~a%" v)))))

;; nerd-font glyph codepoints (numeric so the source stays ASCII)
(defparameter *g-overview* #xF02C1)
(defparameter *g-search*   #x0F002)
(defparameter *g-apps*     #xF003B)
(defparameter *g-term*     #x0F120)
(defparameter *g-web*      #x0F268)
(defparameter *g-files*    #x0F07B)
(defparameter *g-edit*     #x0F121)
(defparameter *g-vol*      #x0F028)
(defparameter *g-mute*     #x0F026)
(defparameter *g-media*    #x0F001)
(defparameter *g-prev*     #x0F048)
(defparameter *g-pause*    #x0F04C)
(defparameter *g-play*     #x0F04B)
(defparameter *g-next*     #x0F051)
(defparameter *g-net*      #x0F1EB)
(defparameter *g-system*   #x0F007)
(defparameter *g-lock2*    #x0F023)
(defparameter *g-logout*   #x0F08B)
(defparameter *g-reboot*   #x0F021)
(defparameter *g-suspend*  #x0F186)
(defparameter *g-off*      #x0F011)
(defparameter *g-cpu*      #x0F2DB)
(defparameter *g-ram*      #x0F1C0)
(defparameter *g-temp*     #x0F2C9)
(defparameter *g-bri*      #x0F185)

;;;; The sidebar, declared as composable widgets. Each defwidget is a component
;;;; (like an eww defwidget); it reads cells, so a cell change re-renders it.

(defwidget ws-item (w)
  (icon (princ-to-string (getf w :idx))
        :on-click (%sh (format nil "niri msg action focus-workspace ~a" (getf w :idx)))
        :face (cond ((getf w :urgent)  :constant)
                    ((getf w :focused) :function-name)
                    (t                 :comment))))

(defwidget sidebar-top ()
  (column :align :center :spacing 1
    (icon *g-overview* :on-click (%sh "niri msg action toggle-overview")
                       :hint "Overview" :face :comment)
    (icon *g-search*   :on-click (%sh "cd ~ && setsid -f bb ~/.config/eww/niri-window-switch.bb")
                       :hint "Search windows" :face :comment)
    (mapcar #'ws-item (%cell :workspaces nil))))

(defwidget sidebar-apps ()
  (column :align :center :spacing 1
    (icon *g-apps*  :on-click (%sh "setsid -f fuzzel")        :hint "Applications")
    (icon *g-term*  :on-click (%sh "setsid -f alacritty")     :hint "Terminal")
    (icon *g-web*   :on-click (%sh "setsid -f google-chrome") :hint "Browser")
    (icon *g-files* :on-click (%sh "setsid -f nautilus")      :hint "Files")
    (icon *g-edit*  :on-click (%sh "cd ~ && emacsclient -c -n") :hint "Editor")))

(defwidget sidebar-tray ()
  (multiple-value-bind (s m h) (decode-universal-time (get-universal-time))
    (declare (ignore s))
    (column :align :center :spacing 1
      (icon *g-vol*    :on-click (%toggle "audio")   :hint "Volume"  :face :string)
      (icon *g-media*  :on-click (%toggle "media")   :hint "Media"   :face :string)
      (icon *g-net*    :on-click (%toggle "network") :hint "Network" :face :string)
      (button :on-click (%toggle "calendar") :hint "Calendar"
        (column :align :center
          (label (format nil "~2,'0d" h) :face :variable-param)
          (label (format nil "~2,'0d" m) :face :comment)))
      (icon *g-system* :on-click (%toggle "ctl") :hint "System" :face :function-name))))

(defwidget sidebar ()
  (column :align :center
    (sidebar-top)
    (gap)
    (sidebar-apps)
    (gap)
    (sidebar-tray)))

(defparameter *bar-cols* 4)
(defparameter *bar-rows* 40)
(defvar *bar-view* nil)
(defvar *bar-root* nil)
(defvar *bar-cells* #())
(defvar *bar-count* 0)

(defun build-bar-cells (cli)
  "The view thunk: build + render the sidebar to a styled cell grid at the
surface's full height, keeping the root for hit-testing. Returns the cells."
  (declare (ignore cli))
  (let* ((root (sidebar))
         (lay (make-instance 'pine.layout:layout :root root
                             :width *bar-cols* :height *bar-rows*)))
    (setf *bar-root* root)
    (multiple-value-bind (lines cells n) (pine.layout:render-layout-grid lay)
      (declare (ignore lines))
      (setf *bar-cells* cells *bar-count* n)
      cells)))



;;;; Drawing + input

(defparameter *bar-cell-w* 9d0)   ; measured from the font on first paint
(defparameter *bar-cell-h* 20d0)
(defparameter *bar-font* 14d0)
(defparameter *bar-ascent* 15d0)
(defparameter *bar-x0* 8d0)
(defvar *bar-measured* nil)

(cffi:defcallback %bar-draw :void ((area :pointer) (cr :pointer)
                                   (width :int) (height :int) (data :pointer))
  (declare (ignore area data))
  (let ((cairo:*context* (make-instance 'cairo:context :pointer cr
                                        :width width :height height :pixel-based-p nil)))
    (cairo:set-source-rgb 0.09d0 0.09d0 0.14d0)
    (cairo:paint)
    (cairo:select-font-face pine.surface:*font-family* :normal :normal)
    (cairo:set-font-size *bar-font*)
    ;; hit-testing must use the font's real advance, not a guess, or click
    ;; columns drift off the rendered glyphs.
    (unless *bar-measured*
      (multiple-value-bind (xb yb w h xadv) (cairo:text-extents "MMMMMMMMMM")
        (declare (ignore xb yb w h))
        (when (plusp xadv) (setf *bar-cell-w* (/ xadv 10d0))))
      (let ((fe (cairo:get-font-extents)))
        (setf *bar-ascent* (cairo:font-ascent fe)
              *bar-cell-h* (cairo:font-height fe)))
      (setf *bar-measured* t))
    (setf *bar-cols* (max 1 (floor width *bar-cell-w*))
          *bar-rows* (max 1 (floor height *bar-cell-h*)))
    ;; render-view runs the thunk (build-bar-cells) with cell tracking, so the
    ;; bar re-subscribes to exactly the cells it read and redraws on change.
    (if *bar-view* (pine.cell:render-view *bar-view*) (build-bar-cells *bar-client*))
    (pine.surface:paint-cell-grid *bar-cells* *bar-count*
                                  *bar-cell-w* *bar-cell-h* *bar-ascent* *bar-x0*)))

(defun on-bar-click (x y)
  ;; run the handler off the UI thread through pine.eval, so a slow or broken
  ;; widget onclick can't hang or crash the bar (or the editor sharing the loop).
  (let* ((col (floor (- x *bar-x0*) *bar-cell-w*))
         (line (floor y *bar-cell-h*))
         (thunk (and *bar-root* (pine.layout:click-thunk *bar-root* line col))))
    (when thunk (pine.eval:evaluate-thunk thunk :package (find-package :pine-user)))))

(defun on-bar-motion (x y)
  "Set the :hint cell to the hint of the widget under the pointer; the echo
strip renders it."
  (let* ((col (floor (- x *bar-x0*) *bar-cell-w*))
         (line (floor y *bar-cell-h*))
         (h (and *bar-root* (pine.layout:hint-at *bar-root* line col))))
    (pine.source:set! :hint (or h ""))))

(defun make-bar (app cli)
  (setf *bar-client* cli)
  (pine.cell:defcell :bar-label "pine")
  (ignore-errors
   (pine.source:start-sources
    (pine.server:actor-system (pine.client:server-of cli))))
  (let ((window (make-application-window :application app))
        (area (make-drawing-area)))
    (setf *bar-view*
          (pine.cell:make-view
           (lambda () (build-bar-cells cli))
           (lambda () (run-in-main-event-loop () (widget-queue-draw area)))))
    (setf (drawing-area-content-width area) 36   ; narrow sidebar; height stretches
          (drawing-area-draw-func area) (list (cffi:callback %bar-draw)
                                              (cffi:null-pointer) (cffi:null-pointer))
          (window-child window) area)
    (let ((click (make-gesture-click)))
      (connect click "pressed"
               (lambda (gesture n-press x y)
                 (declare (ignore gesture n-press))
                 (on-bar-click x y)))
      (widget-add-controller area click))
    (let ((motion (make-event-controller-motion)))
      (connect motion "motion"
               (lambda (c x y) (declare (ignore c)) (on-bar-motion x y)))
      (connect motion "leave"
               (lambda (c) (declare (ignore c)) (pine.source:set! :hint "")))
      (widget-add-controller area motion))
    (configure-bar window)
    (register-panel app "calendar" #'calendar-panel :width 240 :height 120)
    (register-panel app "audio" #'audio-panel :width 340 :height 120)
    (register-panel app "network" #'network-panel :width 420 :height 360)
    (register-panel app "media" #'media-panel :width 380 :height 200)
    (register-panel app "ctl" #'ctl-panel :width 400 :height 280)
    (make-echo app)
    (window-present window)
    (timeout-add 1000 (lambda () (widget-queue-draw area) t))
    window))

;;;; The echo strip: a bottom full-width layer-shell surface that shows the
;;;; :hint cell (set by hover). A second surface on the same substrate.

(defvar *echo-cells* #())
(defvar *echo-count* 0)

(defwidget echo-bar ()
  (label (%cell :hint "") :face :comment))

(cffi:defcallback %echo-draw :void ((area :pointer) (cr :pointer)
                                    (width :int) (height :int) (data :pointer))
  (declare (ignore area data))
  (let ((cairo:*context* (make-instance 'cairo:context :pointer cr
                                        :width width :height height :pixel-based-p nil)))
    (cairo:set-source-rgb 0.09d0 0.09d0 0.14d0)
    (cairo:paint)
    (cairo:select-font-face pine.surface:*font-family* :normal :normal)
    (cairo:set-font-size *bar-font*)
    (%ensure-metrics)
    (let ((lay (make-instance 'pine.layout:layout :root (echo-bar)
                              :width (max 1 (floor width *bar-cell-w*)))))
      (multiple-value-bind (lines cells n) (pine.layout:render-layout-grid lay)
        (declare (ignore lines))
        (setf *echo-cells* cells *echo-count* n)))
    (pine.surface:paint-cell-grid *echo-cells* *echo-count*
                                  *bar-cell-w* *bar-cell-h* *bar-ascent* 8d0)))

(defun configure-echo (window)
  (ensure-layer-shell)
  (let ((p (gobject-introspection-wrapper:object-pointer window)))
    (%init p)
    (%set-namespace p "pine-echo")
    (%set-layer p 2)
    (%set-anchor p 0 t)   ; left
    (%set-anchor p 1 t)   ; right
    (%set-anchor p 3 t)   ; bottom -> a full-width strip along the bottom edge
    (%auto-zone p)))

(defun make-echo (app)
  (let ((window (make-application-window :application app))
        (area (make-drawing-area)))
    (setf (drawing-area-content-height area) 22
          (drawing-area-draw-func area) (list (cffi:callback %echo-draw)
                                              (cffi:null-pointer) (cffi:null-pointer))
          (window-child window) area)
    (pine.cell:cell-subscribe (pine.cell:defcell :hint "")
                              (lambda () (run-in-main-event-loop ()
                                           (widget-queue-draw area))))
    (configure-echo window)
    (window-present window)
    window))


;;;; Panels — layer-shell overlay surfaces rendering a widget tree to cells.
;;;; Each is a second surface on the same substrate: a builder thunk -> node
;;;; tree -> cells, painted by the shared painter, clicks through pine.eval. One
;;;; panel shows at a time; toggling one closes the others.

(defstruct panel name builder window area view root (cells #()) (count 0)
                 (width 400) (height 320) (visible nil))

(defvar *panels* (make-hash-table :test 'equal))
(defvar *panels-by-area* (make-hash-table))

(defun configure-panel (window)
  "Anchor WINDOW as a bottom-left overlay layer-shell surface."
  (ensure-layer-shell)
  (let ((p (gobject-introspection-wrapper:object-pointer window)))
    (%init p)
    (%set-namespace p "pine-panel")
    (%set-layer p 3)          ; overlay
    (%set-anchor p 0 t)       ; left
    (%set-anchor p 3 t)))     ; bottom

(defun build-panel-cells (panel)
  (let* ((root (funcall (panel-builder panel)))
         (cols (max 10 (floor (panel-width panel) *bar-cell-w*)))
         (lay (make-instance 'pine.layout:layout :root root :width cols)))
    (setf (panel-root panel) root)
    (multiple-value-bind (lines cells n) (pine.layout:render-layout-grid lay)
      (declare (ignore lines))
      (setf (panel-cells panel) cells (panel-count panel) n)
      cells)))

(defun %ensure-metrics ()
  (unless *bar-measured*
    (multiple-value-bind (xb yb w h xadv) (cairo:text-extents "MMMMMMMMMM")
      (declare (ignore xb yb w h))
      (when (plusp xadv) (setf *bar-cell-w* (/ xadv 10d0))))
    (let ((fe (cairo:get-font-extents)))
      (setf *bar-ascent* (cairo:font-ascent fe)
            *bar-cell-h* (cairo:font-height fe)))
    (setf *bar-measured* t)))

(cffi:defcallback %panel-draw :void ((area :pointer) (cr :pointer)
                                     (width :int) (height :int) (data :pointer))
  (declare (ignore data))
  (let ((panel (gethash (cffi:pointer-address area) *panels-by-area*)))
    (when panel
      (let ((cairo:*context* (make-instance 'cairo:context :pointer cr
                                            :width width :height height :pixel-based-p nil)))
        (cairo:set-source-rgb 0.10d0 0.10d0 0.15d0)
        (cairo:paint)
        (cairo:select-font-face pine.surface:*font-family* :normal :normal)
        (cairo:set-font-size *bar-font*)
        (%ensure-metrics)
        (if (panel-view panel)
            (pine.cell:render-view (panel-view panel))
            (build-panel-cells panel))
        (pine.surface:paint-cell-grid (panel-cells panel) (panel-count panel)
                                      *bar-cell-w* *bar-cell-h* *bar-ascent* 8d0)))))

(defun on-panel-click (panel x y)
  (let* ((col (floor (- x 8d0) *bar-cell-w*))
         (line (floor y *bar-cell-h*))
         (thunk (and (panel-root panel)
                     (pine.layout:click-thunk (panel-root panel) line col))))
    (when thunk (pine.eval:evaluate-thunk thunk :package (find-package :pine-user)))))

(defun register-panel (app name builder &key (width 400) (height 320))
  "Create a hidden overlay panel NAME whose content is BUILDER (a function of the
client returning a node tree). Show it with toggle-panel."
  (let* ((window (make-application-window :application app))
         (area (make-drawing-area))
         (panel (make-panel :name name :builder builder :window window :area area
                            :width width :height height)))
    (setf (drawing-area-content-width area) width
          (drawing-area-content-height area) height
          (drawing-area-draw-func area) (list (cffi:callback %panel-draw)
                                              (cffi:null-pointer) (cffi:null-pointer))
          (window-child window) area)
    (setf (gethash (cffi:pointer-address
                    (gobject-introspection-wrapper:object-pointer area))
                   *panels-by-area*)
          panel)
    (setf (panel-view panel)
          (pine.cell:make-view (lambda () (build-panel-cells panel))
                               (lambda () (run-in-main-event-loop ()
                                            (widget-queue-draw area)))))
    (let ((click (make-gesture-click)))
      (connect click "pressed"
               (lambda (gesture n-press x y)
                 (declare (ignore gesture n-press))
                 (on-panel-click panel x y)))
      (widget-add-controller area click))
    (configure-panel window)
    (setf (gethash name *panels*) panel)
    panel))

(defun show-panel (panel)
  (window-present (panel-window panel))
  (setf (panel-visible panel) t))

(defun hide-panel (panel)
  (setf (widget-visible-p (panel-window panel)) nil
        (panel-visible panel) nil))

(defun toggle-panel (name)
  "Show panel NAME, hiding any other open panel. Must run on the UI thread."
  (let ((panel (gethash name *panels*)))
    (when panel
      (if (panel-visible panel)
          (hide-panel panel)
          (progn
            (maphash (lambda (k p)
                       (declare (ignore k))
                       (when (and (panel-visible p) (not (eq p panel)))
                         (hide-panel p)))
                     *panels*)
            (show-panel panel))))))

(defwidget calendar-panel ()
  "Placeholder panel: today's date. Exercises the panel surface end to end."
  (multiple-value-bind (s m h d mo y) (decode-universal-time (get-universal-time))
    (declare (ignore s m h))
    (column :align :center
      (label (format nil "~4,'0d-~2,'0d-~2,'0d" y mo d) :face :function-name)
      (label "calendar" :face :comment))))

(defwidget audio-panel ()
  "The audio panel, authored declaratively: header, mute toggle, a live volume
slider whose on-change drives wpctl, and the percentage. Reads the :vol/:muted
cells (fed by the audio source), so it re-renders when they change."
  (let ((vol (%cell :vol 0)) (muted (%cell :muted nil)))
    (column :spacing 1
      (label "Audio" :face :function-name)
      (row :spacing 1 :align :center
        (button :on-click (%sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
          (icon (if muted *g-mute* *g-vol*) :face :string))
        (meter :value vol :min 0 :max 100 :track 20 :on-change #'%set-volume)
        (label (format nil "~3d%" vol) :face :comment)))))

(defwidget wifi-row (n)
  (button :on-click (lambda () (pine.source:select! (getf n :ssid)))
    (row :spacing 1
      (icon *g-net* :face (cond ((equal (getf n :sig) "hi")  :string)
                                ((equal (getf n :sig) "mid") :variable-param)
                                (t :comment)))
      (label (getf n :ssid) :face (if (getf n :in_use) :function-name :default))
      (label (if (getf n :secure) " lock" "")   :face :comment)
      (label (if (getf n :in_use) " *" "")       :face :function-name))))

(defwidget act-btn (a)
  (button :on-click (lambda () (pine.source:act! (getf a :kind)))
    (label (getf a :label)
           :face (cond ((equal (getf a :style) "go") :string)
                       ((equal (getf a :style) "no") :constant)
                       (t :comment)))))

(defwidget network-panel ()
  "The network panel: status, a scrollable wifi list whose rows call select!,
and action buttons that call act! -- the eww nREPL callbacks as in-process
closures. Reads :net/:netlist/:netactions."
  (let ((net  (%cell :net ""))
        (list (%cell :netlist nil))
        (acts (%cell :netactions nil)))
    (column :spacing 1
      (label "Network" :face :function-name)
      (label (if (plusp (length net)) net "Disconnected")
             :face (if (plusp (length net)) :string :comment))
      (viewport :height 10
        (column (mapcar #'wifi-row list)))
      (row :spacing 2 :align :center (mapcar #'act-btn acts)))))

(defun %emms (form) (%sh (format nil "emacsclient -e '~a'" form)))
(defun %emms-seek (v)
  (ignore-errors
    (uiop:launch-program
     (list "emacsclient" "-e" (format nil "(emms-seek-to ~a)" v)))))

(defwidget media-panel ()
  "The media panel: title/artist, a seek slider driving EMMS, and prev/pause/next
transport. Reads the :media cell (polled from the emacs daemon)."
  (let* ((m (%cell :media nil))
         (status (or (getf m :status) "Stopped"))
         (len (max 1 (or (getf m :length) 1))))
    (column :spacing 1
      (label "Media" :face :function-name)
      (label status :face (if (equal status "Playing") :string :comment))
      (label (or (getf m :title) "")  :face :default)
      (label (or (getf m :artist) "") :face :comment)
      (meter :value (or (getf m :pos) 0) :min 0 :max len :track 24 :on-change #'%emms-seek)
      (row :spacing 3 :align :center
        (button :on-click (%emms "(emms-previous)") (icon *g-prev* :face :string))
        (button :on-click (%emms "(emms-pause)")
          (icon (if (equal status "Playing") *g-pause* *g-play*) :face :string))
        (button :on-click (%emms "(emms-next)") (icon *g-next* :face :string))))))

(defun %set-brightness (v)
  (ignore-errors (uiop:launch-program (list "brightnessctl" "set" (format nil "~a%" v)))))

(defwidget gauge (glyph value)
  (row :spacing 1 :align :center
    (icon glyph :face :string)
    (meter :value value :min 0 :max 100 :track 12 :filled-face :string :empty-face :comment)
    (label (format nil "~3d" value) :face :default)))

(defwidget ctl-panel ()
  "The control panel: power actions, cpu/ram/temp gauges, and vol/brightness
sliders. Reads :sys/:vol/:bri."
  (let ((sys (%cell :sys nil)) (vol (%cell :vol 0)) (bri (%cell :bri 50)))
    (column :spacing 1
      (label "System" :face :function-name)
      (row :spacing 2 :align :center
        (button :on-click (%sh "loginctl lock-session") (icon *g-lock2* :face :string))
        (button :on-click (%sh "niri msg action quit")  (icon *g-logout* :face :variable-param))
        (button :on-click (%sh "loginctl reboot")       (icon *g-reboot* :face :variable-param))
        (button :on-click (%sh "loginctl suspend")      (icon *g-suspend* :face :comment))
        (button :on-click (%sh "loginctl poweroff")     (icon *g-off* :face :constant)))
      (gauge *g-cpu*  (or (getf sys :cpu) 0))
      (gauge *g-ram*  (or (getf sys :ram) 0))
      (gauge *g-temp* (or (getf sys :temp) 0))
      (row :spacing 1 :align :center
        (icon *g-vol* :face :string)
        (meter :value vol :min 0 :max 100 :track 18 :on-change #'%set-volume))
      (row :spacing 1 :align :center
        (icon *g-bri* :face :variable-param)
        (meter :value bri :min 0 :max 100 :track 18 :on-change #'%set-brightness)))))
