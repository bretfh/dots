(defpackage #:pine.cell
  (:use #:cl)
  (:export #:cell #:make-cell #:defcell #:find-cell #:cell-name
           #:cell-value #:cell-ref #:set-cell #:update-cell
           #:cell-subscribe #:cell-unsubscribe
           #:reactive-view #:make-view #:render-view #:dispose-view))

(in-package #:pine.cell)

;;;; Reactive cells: the substrate's answer to eww vars + the broker's state
;;;; atom. A cell holds a value, DEDUPS on write (per its test) so identical
;;;; values never re-render, and notifies subscribers on real change. Reads
;;;; inside a tracked render record a dependency automatically, so a widget just
;;;; reads a cell and re-renders when it changes -- no manual wiring.

(defstruct (cell (:constructor %make-cell) (:copier nil))
  (name        nil)
  (value       nil)
  (test        #'equal :type function)
  (subscribers nil)
  (lock        (bordeaux-threads:make-lock)))

(defvar *cells* (make-hash-table :test 'eq)
  "Named cell registry, so widgets bind by name and sources update by name.")

(defun make-cell (&key value (test #'equal) name)
  (let ((c (%make-cell :value value :test test :name name)))
    (when name (setf (gethash name *cells*) c))
    c))

(defun find-cell (name) (gethash name *cells*))

(defmacro defcell (name &optional value &key (test '#'equal))
  "Get or create the named cell (idempotent, so redefining a widget file is safe)."
  `(or (find-cell ,name) (make-cell :name ,name :value ,value :test ,test)))

;;;; Dependency tracking: when bound, collects the cells read during a render.

(defvar *tracking* nil)

(defun cell-ref (cell)
  (when *tracking* (setf (gethash cell *tracking*) t))
  (bordeaux-threads:with-lock-held ((cell-lock cell)) (cell-value cell)))

(defun set-cell (cell new)
  "Set CELL to NEW; notify subscribers only when it actually changed. Thread
safe; subscribers run outside the lock. Returns non-nil if it changed."
  (let (changed subs)
    (bordeaux-threads:with-lock-held ((cell-lock cell))
      (unless (funcall (cell-test cell) (cell-value cell) new)
        (setf (cell-value cell) new changed t
              subs (copy-list (cell-subscribers cell)))))
    (when changed
      (dolist (s subs) (ignore-errors (funcall (cdr s)))))
    changed))

(defun update-cell (cell fn)
  "Set CELL to (FN old-value)."
  (set-cell cell (funcall fn (cell-ref cell))))

(defun cell-subscribe (cell thunk)
  (let ((id (list :sub)))
    (bordeaux-threads:with-lock-held ((cell-lock cell))
      (push (cons id thunk) (cell-subscribers cell)))
    id))

(defun cell-unsubscribe (cell id)
  (bordeaux-threads:with-lock-held ((cell-lock cell))
    (setf (cell-subscribers cell)
          (remove id (cell-subscribers cell) :key #'car :test #'eq))))

(defun call-with-tracking (thunk)
  "Run THUNK; return (values result list-of-cells-read)."
  (let ((tbl (make-hash-table :test 'eq)))
    (let ((*tracking* tbl))
      (let ((result (funcall thunk)))
        (values result (loop for k being the hash-keys of tbl collect k))))))

;;;; A reactive view: a THUNK plus an ON-CHANGE callback. Rendering runs the
;;;; thunk with tracking, then subscribes ON-CHANGE to exactly the cells it
;;;; read; the next render re-subscribes to the (possibly different) new set.

(defstruct (reactive-view (:constructor %make-view))
  thunk on-change (subs nil))

(defun make-view (thunk on-change)
  (%make-view :thunk thunk :on-change on-change))

(defun %clear-subs (view)
  (mapc #'funcall (reactive-view-subs view))
  (setf (reactive-view-subs view) nil))

(defun render-view (view)
  "Run the view's thunk, (re)subscribe to the cells it depends on, return its
result."
  (%clear-subs view)
  (multiple-value-bind (result deps)
      (call-with-tracking (reactive-view-thunk view))
    (setf (reactive-view-subs view)
          (mapcar (lambda (c)
                    (let ((id (cell-subscribe c (reactive-view-on-change view))))
                      (lambda () (cell-unsubscribe c id))))
                  deps))
    result))

(defun dispose-view (view)
  (%clear-subs view))
