(in-package :arc)

(defvar *gemini-api-key* (uiop:getenv "GEMINI_API_KEY"))
(defvar *conversation-history* nil)
(defvar *agent-mode-keymap* (make-keymap))
(defvar *agent-client* nil)
(defvar *last-conversation-position* 0 "Track where the last conversation ended")

;;; Provider system
(defclass lem-gemini-provider ()
  ((api-key :initarg :api-key :accessor provider-api-key)
   (base-url :initform "https://generativelanguage.googleapis.com" :accessor provider-base-url)
   (default-model :initarg :model :accessor provider-default-model)))

(defclass lem-llm-client ()
  ((provider :initarg :provider :accessor client-provider)
   (tools :initform nil :accessor client-tools)))

(defun make-gemini-client (&key api-key (model "gemini-2.0-flash-exp"))
  (let ((provider (make-instance 'lem-gemini-provider :api-key api-key :model model)))
    (make-instance 'lem-llm-client :provider provider)))

;;; Tool registry
(defvar *tool-registry* (make-hash-table :test 'equal))

(defun register-tool (name description handler)
  (setf (gethash name *tool-registry*)
        (list :description description :handler handler)))

(defun execute-tool-by-name (name &rest args)
  (let ((tool-info (gethash name *tool-registry*)))
    (if tool-info
        (apply (getf tool-info :handler) args)
        (format nil "Tool ~A not found" name))))

;;; Register tools
(register-tool "get_buffer_content"
  "Get the entire content of the current buffer"
  (lambda ()
    (buffer-text (current-buffer))))

(register-tool "insert_text"
  "Insert text at current cursor position"
  (lambda (text)
    (when text
      (insert-string (current-point) text)
      (format nil "Inserted ~D characters" (length text)))))

(register-tool "eval_lisp"
  "Execute Common Lisp code"
  (lambda (code &optional package)
    (when code
      (let* ((pkg (when package (find-package (string-upcase package))))
             (*package* (or pkg *package*)))
        (handler-case
            (let ((result (eval (read-from-string code))))
              (handler-case
                  (format nil "~S" result)
                (print-not-readable ()
                  (format nil "~A" result))
                (error ()
                  (format nil "#<~A>" (type-of result)))))
          (error (e) (format nil "Error: ~A" e)))))))

(register-tool "list_directory"
  "List directory contents"
  (lambda (path &optional show-hidden)
    (handler-case
        (let* ((resolved-path (if (uiop:absolute-pathname-p path)
                                  path
                                  (merge-pathnames path (uiop:getcwd))))
               (entries (uiop:directory-files resolved-path))
               (directories (uiop:subdirectories resolved-path))
               (all-entries (append directories entries)))
          (format nil "~{~A~%~}" 
                  (mapcar #'namestring
                          (if show-hidden
                              all-entries
                              (remove-if (lambda (entry)
                                           (let ((name (file-namestring entry)))
                                             (and (> (length name) 0)
                                                  (char= (char name 0) #\.))))
                                         all-entries)))))
      (error ()
        (format nil "Directory ~A not found" path)))))

(register-tool "read_file"
  "Read file contents"
  (lambda (path &optional max-lines)
    (let ((file-path (uiop:file-exists-p path)))
      (if file-path
          (handler-case
              (let ((lines (uiop:read-file-lines file-path)))
                (when (and max-lines (stringp max-lines))
                  (setf lines (subseq lines 0 (min (parse-integer max-lines :junk-allowed t) 
                                                    (length lines)))))
                (format nil "~{~A~%~}" lines))
            (error (e) (format nil "Error reading file: ~A" e)))
          (format nil "File ~A not found" path)))))

(register-tool "execute_command"
  "Execute shell command"
  (lambda (command &optional working-directory)
    (handler-case
        (let ((output (with-output-to-string (stream)
                        (let ((process (uiop:launch-program 
                                        command
                                        :output stream
                                        :error-output stream
                                        :directory working-directory)))
                          (uiop:wait-process process)))))
          (if (> (length output) 1000)
              (concatenate 'string (subseq output 0 997) "...")
            output))
      (error (e) (format nil "Command execution error: ~A" e)))))

;;; JSON helpers
(defun escape-json-string (str)
  "Properly escape strings for JSON"
  (if (null str)
      ""
      (with-output-to-string (s)
        (loop for c across str do
          (case c
            (#\" (write-string "\\\"" s))
            (#\\ (write-string "\\\\" s))
            (#\Newline (write-string "\\n" s))
            (#\Return (write-string "\\r" s))
            (#\Tab (write-string "\\t" s))
            (otherwise (write-char c s)))))))

;;; Build JSON request
(defun build-request-json (conversation-history)
  "Build JSON request for Gemini API"
  (let ((contents-json 
         (format nil "[~{~A~^,~}]"
                 (mapcar (lambda (msg)
                           (format nil "{\"role\":\"~A\",\"parts\":[~{~A~^,~}]}"
                                   (gethash "role" msg)
                                   (mapcar (lambda (part)
                                             (format nil "{\"text\":\"~A\"}"
                                                     (escape-json-string (gethash "text" part))))
                                           (gethash "parts" msg))))
                         conversation-history)))
        (tools-json "{\"functionDeclarations\":[{\"name\":\"get_buffer_content\",\"description\":\"Get the entire content of the current buffer\"},{\"name\":\"insert_text\",\"description\":\"Insert text at cursor position\",\"parameters\":{\"type\":\"object\",\"properties\":{\"text\":{\"type\":\"string\"}},\"required\":[\"text\"]}},{\"name\":\"eval_lisp\",\"description\":\"Execute Common Lisp code\",\"parameters\":{\"type\":\"object\",\"properties\":{\"code\":{\"type\":\"string\"},\"package\":{\"type\":\"string\"}},\"required\":[\"code\"]}},{\"name\":\"list_directory\",\"description\":\"List directory contents\",\"parameters\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"},\"show_hidden\":{\"type\":\"boolean\"}},\"required\":[\"path\"]}},{\"name\":\"read_file\",\"description\":\"Read file contents\",\"parameters\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"},\"max_lines\":{\"type\":\"string\"}},\"required\":[\"path\"]}},{\"name\":\"execute_command\",\"description\":\"Execute shell command\",\"parameters\":{\"type\":\"object\",\"properties\":{\"command\":{\"type\":\"string\"},\"working_directory\":{\"type\":\"string\"}},\"required\":[\"command\"]}}]}"))
    (format nil "{\"contents\":~A,\"tools\":[~A],\"generationConfig\":{\"maxOutputTokens\":4000}}"
            contents-json tools-json)))

;;; Make system message
(defun make-system-message ()
  "Create system message"
  (let ((msg (make-hash-table :test 'equal))
        (parts (make-hash-table :test 'equal)))
    (setf (gethash "text" parts) 
          "You are an AI assistant running inside Lem editor written in Common Lisp. You have access to tools for manipulating buffers, evaluating Lisp code, and interacting with the file system. The current package is accessible via *package*. Use tools when needed to answer questions or perform tasks.")
    (setf (gethash "role" msg) "user")
    (setf (gethash "parts" msg) (list parts))
    msg))

;;; Chat function
(defun chat-gemini-with-conversation (client conversation-history)
  (let* ((provider (client-provider client))
         (ordered-history (reverse conversation-history))
         (enhanced-history 
          (if (and ordered-history 
                   (string= (gethash "role" (first ordered-history)) "user"))
              (cons (make-system-message) ordered-history)
              ordered-history)))
    (handler-case
        (let* ((url (format nil "~A/v1beta/models/~A:generateContent?key=~A"
                            (provider-base-url provider)
                            (provider-default-model provider)
                            (provider-api-key provider)))
               (json-string (build-request-json enhanced-history))
               (response (dexador:post url
                                       :content json-string
                                       :headers '(("Content-Type" . "application/json"))))
               (parsed-response (yason:parse response))
               (candidates (gethash "candidates" parsed-response))
               (candidate (when candidates
                            (if (vectorp candidates)
                                (elt candidates 0)
                                (first candidates))))
               (content (when candidate (gethash "content" candidate)))
               (parts (when content (gethash "parts" content)))
               (text-parts nil)
               (function-calls nil))
          
          (when parts
            (if (vectorp parts)
                (loop for part across parts do
                  (let ((text (gethash "text" part))
                        (function-call (gethash "functionCall" part)))
                    (cond
                      (text (push text text-parts))
                      (function-call
                       (push (list :name (gethash "name" function-call)
                                   :args (gethash "args" function-call))
                             function-calls)))))
                (dolist (part parts)
                  (let ((text (gethash "text" part))
                        (function-call (gethash "functionCall" part)))
                    (cond
                      (text (push text text-parts))
                      (function-call
                       (push (list :name (gethash "name" function-call)
                                   :args (gethash "args" function-call))
                             function-calls)))))))
          
          (values (format nil "~{~A~^~%~}" (nreverse text-parts))
                  (nreverse function-calls)))
      (error (e)
        (format nil "API error: ~A" e)))))

;;; Extract tool arguments
(defun extract-tool-args (tool-name args)
  (cond
    ((string= tool-name "get_buffer_content") '())
    ((string= tool-name "insert_text") 
     (list (gethash "text" args)))
    ((string= tool-name "eval_lisp") 
     (list (gethash "code" args) (gethash "package" args)))
    ((string= tool-name "list_directory")
     (list (gethash "path" args) (gethash "show_hidden" args)))
    ((string= tool-name "read_file")
     (list (gethash "path" args) (gethash "max_lines" args)))
    ((string= tool-name "execute_command")
     (list (gethash "command" args) (gethash "working_directory" args)))
    (t '())))

;;; Agent Mode
(define-major-mode agent-mode ()
    (:name "Agent"
     :keymap *agent-mode-keymap*)
  "LLM Agent mode"
  
  (unless *agent-client*
    (when *gemini-api-key*
      (setf *agent-client* (make-gemini-client :api-key *gemini-api-key*))))
  
  (insert-string (current-point) "Agent Mode Active - Type your message and press C-c C-c to send.\n")
  (setf *last-conversation-position* (length (buffer-text (current-buffer)))))

;;; Send buffer command
(define-command agent-send-buffer () ()
  (unless *agent-client*
    (message "No agent client. Check GEMINI_API_KEY.")
    (return-from agent-send-buffer))
  
  (let* ((full-text (buffer-text (current-buffer)))
         (input (if (< *last-conversation-position* (length full-text))
                    (subseq full-text *last-conversation-position*)
                    "")))
    (when (and input (not (string= (string-trim '(#\Space #\Tab #\Newline) input) "")))
      ;; Add user message to history
      (let ((user-msg (make-hash-table :test 'equal))
            (parts (make-hash-table :test 'equal)))
        (setf (gethash "text" parts) (string-trim '(#\Space #\Tab #\Newline) input))
        (setf (gethash "role" user-msg) "user")
        (setf (gethash "parts" user-msg) (list parts))
        (push user-msg *conversation-history*))
      
      (setf *last-conversation-position* (length full-text))
      (insert-string (current-point) (format nil "~%User: ~A~%~%" 
                                              (string-trim '(#\Space #\Tab #\Newline) input)))
      
      (message "Calling Gemini API...")
      (multiple-value-bind (response function-calls)
          (chat-gemini-with-conversation *agent-client* *conversation-history*)
        
        ;; Execute tools if requested
        (when function-calls
          (dolist (call function-calls)
            (let* ((tool-name (getf call :name))
                   (args (getf call :args))
                   (tool-args (extract-tool-args tool-name args))
                   (result (apply #'execute-tool-by-name tool-name tool-args)))
              (insert-string (current-point) 
                             (format nil "[Tool: ~A] ~A~%~%" tool-name result))
              
              ;; Add tool result to conversation
              (let ((tool-msg (make-hash-table :test 'equal))
                    (parts (make-hash-table :test 'equal)))
                (setf (gethash "text" parts) 
                      (format nil "Tool ~A result: ~A" tool-name result))
                (setf (gethash "role" tool-msg) "user")
                (setf (gethash "parts" tool-msg) (list parts))
                (push tool-msg *conversation-history*))))
          
          ;; Get final response after tools
          (when function-calls
            (multiple-value-bind (final-response more-calls)
                (chat-gemini-with-conversation *agent-client* *conversation-history*)
              (setf response final-response))))
        
        ;; Add assistant response to history
        (let ((assistant-msg (make-hash-table :test 'equal))
              (parts (make-hash-table :test 'equal)))
          (setf (gethash "text" parts) response)
          (setf (gethash "role" assistant-msg) "model")
          (setf (gethash "parts" assistant-msg) (list parts))
          (push assistant-msg *conversation-history*))
        
        (insert-string (current-point) (format nil "Agent: ~A~%~%" response))
        (setf *last-conversation-position* (length (buffer-text (current-buffer))))))))

(define-command agent-reset-conversation () ()
  (setf *conversation-history* nil)
  (setf *last-conversation-position* 0)
  (message "Conversation reset"))

(define-command start-agent () ()
  (let ((buffer (make-buffer "*Agent Chat*")))
    (switch-to-buffer buffer)
    (setf *last-conversation-position* 0)
    (setf *conversation-history* nil)
    (agent-mode)))

;;; Key bindings
(define-key *agent-mode-keymap* "C-c C-c" 'agent-send-buffer)
(define-key *agent-mode-keymap* "C-c C-r" 'agent-reset-conversation)