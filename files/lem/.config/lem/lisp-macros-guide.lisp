;;; Common Lisp Macros Reference Guide
;;; Essential macros for Lem configuration and Common Lisp programming

;;; === LOOP - Powerful Iteration ===

;; Basic iteration
(loop for i from 1 to 5
      collect i)  ; => (1 2 3 4 5)

;; Iterate over lists
(loop for item in '(a b c d)
      collect (list item (symbol-name item)))

;; With conditions
(loop for x from 1 to 10
      when (evenp x)
        collect x)  ; => (2 4 6 8 10)

;; Accumulation
(loop for i from 1 to 5
      sum i)  ; => 15

;; Multiple clauses
(loop for key in '(:name :age :city)
      for value in '("Alice" 30 "NYC")
      collect (cons key value))


;;; === FORMAT - String Formatting & Output ===

;; Output to stdout (nil = stdout, t = *standard-output*)
(format t "Hello, ~a!~%" "World")  ; ~% = newline

;; Return string (nil → stdout, but any stream or t works)
(format nil "Number: ~d" 42)  ; => "Number: 42"

;; Common directives:
;; ~a - aesthetic (human readable)
;; ~s - S-expression (with quotes/escapes)
;; ~d - decimal integer
;; ~f - floating point
;; ~% - newline
;; ~~ - literal tilde

(format t "~a is ~d years old~%" "Bob" 25)
(format nil "List: ~{~a~^, ~}" '(1 2 3))  ; => "List: 1, 2, 3"
(format nil "~10a~10d" "Name" 123)  ; Fixed width columns


;;; === SETF - Generalized Assignment ===

;; Set variables
(let ((x 10))
  (setf x 20)
  x)  ; => 20

;; Set multiple at once
(let (a b)
  (setf a 1
        b 2)
  (list a b))  ; => (1 2)

;; Set list elements
(let ((lst '(a b c)))
  (setf (nth 1 lst) 'NEW)
  lst)  ; => (A NEW C)

;; Set hash table entries
(let ((ht (make-hash-table)))
  (setf (gethash :key ht) "value")
  (gethash :key ht))  ; => "value"

;; Set property lists
(let ((plist '()))
  (setf (getf plist :name) "Alice")
  plist)  ; => (:NAME "Alice")


;;; === COND - Multi-Way Conditionals ===

;; Like if-else-if chain
(defun classify-number (n)
  (cond
    ((< n 0) :negative)
    ((= n 0) :zero)
    ((< n 10) :small-positive)
    (t :large-positive)))  ; t = default case

;; With multiple forms per clause
#|
(cond
  ((null lst)
   (format t "Empty!~%")
   nil)
  ((= (length lst) 1)
   (format t "Single item~%")
   (car lst))
  (t
   (format t "Multiple items~%")
   lst))
|#


;;; === WHEN / UNLESS - Single-Branch Conditionals ===

#|
(when (> x 10)
  (format t "Big number~%")
  (setf x 10))  ; Implicit progn

(unless (zerop count)
  (process-items))
|#


;;; === CASE - Switch Statement ===

#|
(case operator
  (+ (+ a b))
  (- (- a b))
  (* (* a b))
  (/ (/ a b))
  (otherwise (error "Unknown operator")))
|#


;;; === DOLIST / DOTIMES - Simple Iteration ===

#|
(dolist (file files)
  (process-file file))

(dotimes (i 5)
  (format t "~d " i))  ; 0 1 2 3 4
|#


;;; === LET / LET* - Local Bindings ===

;; Parallel binding
(let ((x 1)
      (y 2))
  (+ x y))

;; Sequential binding (can reference previous)
(let* ((x 1)
       (y (+ x 1)))
  y)  ; => 2


;;; === DESTRUCTURING-BIND - Pattern Matching ===

(destructuring-bind (cmd &rest args)
    '(move 10 20)
  (format t "Command: ~a, Args: ~a~%" cmd args))


;;; === PUSH / POP - List Stack Operations ===

(let ((stack '()))
  (push 'a stack)
  (push 'b stack)
  stack)  ; => (B A)


;;; === Lem-Specific Examples ===

#|
;; In your lem config, you might use:
(loop for (key . cmd) in '(("C-x C-s" . save-buffer)
                            ("C-x k" . kill-buffer))
      do (lem:define-key lem:*global-keymap* key cmd))

;; Format for logging
(format t "[~a] ~a~%"
        (local-time:now)
        "Operation complete")

;; Conditional config
(cond
  ((string= (uiop:getenv "THEME") "dark")
   (setf *theme* :dark))
  (t
   (setf *theme* :light)))
|#
