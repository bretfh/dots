(in-package :pine.buffer)


;;;; ================================================================
;;;; Faces
;;;; ================================================================

(defclass face ()
  ((fg        :initarg :fg        :accessor fg        :initform nil)
   (bg        :initarg :bg        :accessor bg        :initform nil)
   (bold      :initarg :bold      :accessor bold      :initform nil)
   (italic    :initarg :italic    :accessor italic    :initform nil)
   (underline :initarg :underline :accessor underline :initform nil)))

(defun faces-table ()
  (let ((srv (pine.client:server-of (pine.client:current-client))))
    (or (pine.server:faces srv)
        (setf (pine.server:faces srv) (make-hash-table :test 'eq)))))

(defun defface (name &key fg bg bold italic underline)
  (setf (gethash name (faces-table))
        (make-instance 'face :fg fg :bg bg :bold bold
                             :italic italic :underline underline)))

(defun find-face (name)
  (gethash name (faces-table)))

(defun face-to-plist (f)
  "Serialize a face to a plist for crossing the QML boundary."
  (when f
    (append
     (when (fg f) (list :fg (fg f)))
     (when (bg f) (list :bg (bg f)))
     (when (bold f) (list :bold t))
     (when (italic f) (list :italic t))
     (when (underline f) (list :underline t)))))


(defun install-default-faces ()
  (defface :default       :fg "#cdd6f4")
  (defface :cursor        :bg "#89b4fa")
  (defface :selection     :bg "#45475a")
  (defface :modeline      :fg "#cdd6f4" :bg "#181825")
  (defface :modeline-mode :fg "#89b4fa" :bg "#181825" :bold t)
  (defface :modeline-dim  :fg "#6c7086" :bg "#181825")
  (defface :modeline-faint :fg "#45475a" :bg "#181825")
  (defface :border-active :fg "#89b4fa")
  (defface :border-inactive :fg "#232334")
  (defface :prompt        :fg "#89b4fa" :bold t)
  (defface :completion    :fg "#cdd6f4" :bg "#181825")
  (defface :completion-selected :fg "#cdd6f4" :bg "#333455")
  (defface :keyword         :fg "#cba6f7")
  (defface :string          :fg "#a6e3a1")
  (defface :comment         :fg "#6c7086")
  (defface :function-name   :fg "#89b4fa")
  (defface :variable        :fg "#f5c2e7")
  (defface :variable-param  :fg "#f9e2af")
  (defface :type            :fg "#f9e2af")
  (defface :builtin         :fg "#94e2d5")
  (defface :constant        :fg "#fab387")
  (defface :escape          :fg "#fab387")
  (defface :line-number     :fg "#45475a"))


;;;; Face runs — attributed text

(defclass face-run ()
  ((start-col :initarg :start :accessor run-start :initform 0)
   (end-col   :initarg :end   :accessor run-end   :initform 0)
   (run-face  :initarg :face  :accessor run-face   :initform :default)))

(defclass display-line ()
  ((text :initarg :text :accessor display-text :initform "")
   (runs :initarg :runs :accessor display-runs :initform nil)))

(defun make-display-line (text &optional runs)
  (make-instance 'display-line
    :text text
    :runs (or runs
              (list (make-instance 'face-run
                      :start 0 :end (length text) :face :default)))))

(defun display-line-to-plist (dl)
  "Serialize a display-line for QML: (:text str :runs ((s e face-plist) ...))."
  (list :text (display-text dl)
        :runs (mapcar (lambda (r)
                        (list (run-start r) (run-end r)
                              (face-to-plist (find-face (run-face r)))))
                      (display-runs dl))))
