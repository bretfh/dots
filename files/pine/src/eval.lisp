(defpackage #:pine.eval
  (:use #:cl)
  (:export #:evaluation #:evaluation-id #:evaluation-form #:evaluation-status
           #:evaluation-values #:evaluation-output #:evaluation-condition
           #:evaluation-condition-type #:evaluation-restarts #:evaluation-backtrace
           #:evaluate #:evaluate-string #:evaluate-thunk
           #:list-evaluations #:find-evaluation
           #:pick-restart #:abort-evaluation #:*on-debug*))

(in-package #:pine.eval)

(defvar *on-debug* nil
  "Default surface for an evaluation that enters the debugger: a function of the
evaluation, installed by the editor. Any eval path (C-x C-e, repl, widget
onclick, remote) reaches the same debugger through it.")

;;;; Evaluation as a first-class, off-UI-thread operation. Each eval runs on its
;;;; own thread (so it can block or run forever without touching the editor) and
;;;; produces one uniform EVALUATION object -- form, package, status, values,
;;;; captured output, and on error the condition/restarts/backtrace. An error
;;;; does not drop to a console debugger: the worker captures the restarts and
;;;; BLOCKS, and a surface picks one (invoke-restart) or aborts. Same object for
;;;; C-x C-e, the repl, a widget onclick, or a remote agent.

(defvar *evaluations* nil)
(defvar *counter* 0)
(defvar *current* nil)
(defvar *registry-lock* (bordeaux-threads:make-lock "pine-eval-registry")
  "Guards *evaluations* and *counter*, since any thread (command path, repl,
agent) may start an evaluation concurrently.")

(defstruct (evaluation (:constructor %make-evaluation))
  (id (incf *counter*))
  form
  thunk
  package
  (status :running)                 ; :running :ok :error :aborted
  (values nil)
  (output "")
  condition
  condition-type
  restarts                          ; list of (name-string report-string)
  backtrace
  thread
  on-done
  on-error
  (lock (bordeaux-threads:make-lock))
  (cvar (bordeaux-threads:make-condition-variable))
  (chosen nil))

(defun list-evaluations ()
  (bordeaux-threads:with-lock-held (*registry-lock*) (copy-list *evaluations*)))
(defun find-evaluation (id)
  (bordeaux-threads:with-lock-held (*registry-lock*)
    (find id *evaluations* :key #'evaluation-id)))

(defun %capture-backtrace ()
  (handler-case
      (with-output-to-string (s) (sb-debug:print-backtrace :stream s :count 25))
    (error () "")))

(defun %restart-descriptions (condition)
  (loop for r in (compute-restarts condition)
        collect (list (and (restart-name r) (string (restart-name r)))
                      (handler-case (princ-to-string r) (error () "")))))

(defun eval-debugger-hook (ev condition)
  "Runs on the eval thread when an unhandled error propagates. Records the
condition + restarts + backtrace, notifies the surface, then blocks until a
restart is chosen and invokes it."
  (setf (evaluation-status ev) :error
        (evaluation-condition ev) (handler-case (princ-to-string condition)
                                    (error () "<unprintable condition>"))
        (evaluation-condition-type ev) (string (type-of condition))
        (evaluation-restarts ev) (%restart-descriptions condition)
        (evaluation-backtrace ev) (%capture-backtrace))
  (let ((surface (or (evaluation-on-error ev) *on-debug*)))
    (when surface (ignore-errors (funcall surface ev))))
  (let ((name (bordeaux-threads:with-lock-held ((evaluation-lock ev))
                (loop until (evaluation-chosen ev)
                      do (bordeaux-threads:condition-wait
                          (evaluation-cvar ev) (evaluation-lock ev)))
                (evaluation-chosen ev))))
    (let ((r (or (find name (compute-restarts condition)
                       :key (lambda (x) (and (restart-name x) (string (restart-name x))))
                       :test (lambda (a b) (and a b (string-equal a b))))
                 (find-restart 'abort condition))))
      (when r (invoke-restart r)))))

(defun run-evaluation (ev bindings)
  (let ((*current* ev)
        (out (make-string-output-stream)))
    (unwind-protect
         (progv (mapcar #'car bindings) (mapcar #'cdr bindings)
           (let ((*standard-output* out)
                 (*error-output* out)
                 (*trace-output* out)
                 (*package* (or (evaluation-package ev) (find-package :cl-user)))
                 (sb-ext:*invoke-debugger-hook*
                   (lambda (c hook) (declare (ignore hook)) (eval-debugger-hook ev c))))
             (multiple-value-bind (ok abortp)
                 (with-simple-restart (abort "Abort this evaluation")
                   (setf (evaluation-values ev)
                         (multiple-value-list
                          (if (evaluation-thunk ev)
                              (funcall (evaluation-thunk ev))
                              (eval (evaluation-form ev))))
                         (evaluation-status ev) :ok)
                   t)
               (declare (ignore ok))
               (when abortp (setf (evaluation-status ev) :aborted)))))
      (setf (evaluation-output ev) (get-output-stream-string out))
      (when (evaluation-on-done ev)
        (ignore-errors (funcall (evaluation-on-done ev) ev))))))

(defun evaluate (form &key thunk (package *package*) bindings on-done on-error)
  "Evaluate FORM (or call THUNK) on a fresh thread. Returns the EVALUATION
immediately. BINDINGS is an alist (special-symbol . value) rebound around the
eval (e.g. *client*). ON-DONE / ON-ERROR run on the eval thread."
  (let ((ev (bordeaux-threads:with-lock-held (*registry-lock*)
              ;; id assignment (incf *counter*) and the push share the lock so
              ;; concurrent starts get distinct ids and no lost entries.
              (let ((ev (%make-evaluation :form form :thunk thunk :package package
                                          :on-done on-done :on-error on-error)))
                (push ev *evaluations*)
                ev))))
    (setf (evaluation-thread ev)
          (bordeaux-threads:make-thread
           (lambda () (run-evaluation ev bindings))
           :name (format nil "pine-eval-~a" (evaluation-id ev))))
    ev))

(defun evaluate-thunk (thunk &key (package *package*) bindings on-done on-error)
  "Run THUNK (a nullary function) as an evaluation — a widget onclick handler
can't hang or crash the UI thread."
  (evaluate nil :thunk thunk :package package :bindings bindings
                :on-done on-done :on-error on-error))

(defun evaluate-string (string &key (package *package*) bindings on-done on-error)
  (let ((form (let ((*package* (or package *package*)))
                (read-from-string string))))
    (evaluate form :package package :bindings bindings
                   :on-done on-done :on-error on-error)))

(defun pick-restart (ev name)
  "Resume a debugging evaluation by invoking the restart named NAME."
  (bordeaux-threads:with-lock-held ((evaluation-lock ev))
    (setf (evaluation-chosen ev) (string name))
    (bordeaux-threads:condition-notify (evaluation-cvar ev))))

(defun abort-evaluation (ev)
  "Abort EV: if it is in the debugger, invoke its abort restart; otherwise
interrupt the worker into its abort restart (kills a runaway loop)."
  (if (eq (evaluation-status ev) :error)
      (pick-restart ev "ABORT")
      (ignore-errors
       (bordeaux-threads:interrupt-thread
        (evaluation-thread ev)
        (lambda () (ignore-errors (invoke-restart 'abort)))))))
