(in-package :arc)

(defvar *test-agent-keymap* (make-keymap))

(define-major-mode test-agent-mode ()
    (:name "TestAgent"
     :keymap *test-agent-keymap*)
  "Simple test agent mode"
  (insert-string (current-point) "Test Agent Mode - this should work without yason errors"))

(define-command test-agent () ()
  (let ((buffer (make-buffer "*Test Agent*")))
    (switch-to-buffer buffer)
    (test-agent-mode)))

(define-key *test-agent-keymap* "C-c C-t" 'test-agent)