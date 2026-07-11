(in-package :pine.repl)

(defvar *history* (fset:empty-seq))
(defvar *history-index* -1)

(defun repl-buffer ()
  (pine.client:repl-buffer (pine.client:current-client)))

(defun start-repl ()
  (let* ((client (pine.client:current-client))
         (buf (pine.buffer:make-buffer "*repl*" :content "pine> ")))
    (setf (pine.client:repl-buffer client) buf)
    (pine.mode:set-buffer-mode buf :repl-mode)
    (let* ((snap (sento.actor:ask-s buf '(:get-snapshot) :time-out 5))
           (line (pine.buffer:line-count snap))
           (col (length "pine> ")))
      (sento.actor:tell buf (list :move-point :line (1- line) :col col)))
    buf))

(defun repl-eval (input)
  (setf *history* (fset:with-last *history* input))
  (setf *history-index* -1)
  (cond
    ((and (plusp (length input)) (char= (char input 0) #\!))
     (run-shell-command (subseq input 1)))
    (t (eval-lisp input))))

(defun eval-lisp (input)
  ;; off-thread via pine.eval: a slow/looping/erroring form can't hang the repl,
  ;; and errors reach the shared debugger surface (*on-debug*).
  (pine.eval:evaluate-string
   input
   :package (find-package :cl-user)
   :bindings (list (cons 'pine.client:*client* (pine.client:current-client)))
   :on-done
   (lambda (ev)
     (append-output
      (case (pine.eval:evaluation-status ev)
        (:ok (let ((out (pine.eval:evaluation-output ev)))
               (format nil "~@[~a~%~]~{~s~^~%~}"
                       (and (plusp (length out)) out)
                       (pine.eval:evaluation-values ev))))
        (:aborted "; aborted")
        (t (format nil "; error: ~a" (pine.eval:evaluation-condition ev))))))))

(defun run-shell-command (cmd)
  (handler-case
      (let ((output (uiop:run-program cmd
                                      :output :string
                                      :error-output :string
                                      :ignore-error-status t)))
        (append-output (string-trim '(#\Newline #\Space) output)))
    (error (c)
      (append-output (format nil "shell error: ~a" c)))))

(defun append-output (text)
  (let ((buf (repl-buffer)))
    (when buf
      (sento.actor:tell buf (list :append-with-prompt
                                  :text text
                                  :prompt "pine> ")))))

(defun repl-submit ()
  (let ((buf (repl-buffer)))
    (when buf
      (let* ((state (sento.actor:ask-s buf '(:get-state) :time-out 5))
             (last-line (1- (pine.buffer:line-count-of state)))
             (line-text (fset:@ (pine.buffer:lines state) last-line))
             (input (if (> (length line-text) 6) (subseq line-text 6) "")))
        (when (plusp (length input))
          (repl-eval input))))))
