;;; gptel-tools.el --- gptel tool definitions -*- lexical-binding: t; -*-

(require 'gptel)

(defun gptel-edit-buffer (buffer-name old-string new-string)
  "Replace OLD-STRING with NEW-STRING in BUFFER-NAME."
  (with-current-buffer buffer-name
    (let ((case-fold-search nil))
      (save-excursion
        (goto-char (point-min))
        (let ((count 0))
          (while (search-forward old-string nil t) (setq count (1+ count)))
          (if (= count 0)
              (format "Error: Could not find text to replace in buffer %s" buffer-name)
            (if (> count 1)
                (format "Error: Found %d matches for the text to replace in buffer %s" count buffer-name)
              (goto-char (point-min))
              (search-forward old-string) (replace-match new-string t t)
              (format "Successfully edited buffer %s" buffer-name))))))))

(defun gptel-replace-buffer (buffer-name content)
  "Replace BUFFER-NAME's contents with CONTENT."
  (with-current-buffer buffer-name
    (erase-buffer) (insert content)
    (format "Buffer replaced: %s" buffer-name)))

(defun gptel-edit-file (file-path file-edits)
  "Apply FILE-EDITS to FILE-PATH and ediff with original."
  (if (and file-path (not (string= file-path "")) file-edits)
      (with-current-buffer (get-buffer-create "*edit-file*")
        (erase-buffer) (insert-file-contents (expand-file-name file-path))
        (let ((inhibit-read-only t) (case-fold-search nil)
              (file-name (expand-file-name file-path)) (edit-success nil))
          (dolist (file-edit (seq-into file-edits 'list))
            (when-let ((line-number (plist-get file-edit :line_number))
                       (old-string (plist-get file-edit :old_string))
                       (new-string (plist-get file-edit :new_string))
                       (is-valid-old-string (not (string= old-string ""))))
              (goto-char (point-min)) (forward-line (1- line-number))
              (when (search-forward old-string nil t)
                (replace-match new-string t t) (setq edit-success t))))
          (if edit-success
              (progn (write-file file-name)
                     (ediff-buffers (find-file-noselect file-name) (current-buffer))
                     (format "Successfully edited %s" file-name))
            (format "Failed to edit %s" file-name))))
    (format "Failed to edit %s" file-path)))

(defun gptel-read-documentation (symbol-name)
  "Return docstring for SYMBOL-NAME."
  (let ((sym (intern-soft symbol-name)))
    (cond ((not sym) (format "No documentation found for %s" symbol-name))
          ((fboundp sym) (or (documentation sym) "No documentation available"))
          ((boundp sym) (or (documentation-property sym 'variable-documentation) "No documentation available"))
          (t (format "No documentation found for %s" symbol-name)))))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (code)
                          (condition-case err (prin1-to-string (eval (read code) t))
                            (error (format "Error: %s" (error-message-string err)))))
              :name "eval" :description "Execute any Emacs Lisp code. Full unrestricted access to Emacs."
              :args (list '(:name "code" :type string :description "Elisp code to execute"))
              :category "system"))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (buffer)
                          (unless (buffer-live-p (get-buffer buffer))
                            (error "Error: buffer %s is not live." buffer))
                          (with-current-buffer buffer
                            (buffer-substring-no-properties (point-min) (point-max))))
              :name "read_buffer" :description "Return the contents of an Emacs buffer"
              :args (list '(:name "buffer" :type string :description "The name of the buffer whose contents are to be retrieved"))
              :category "emacs"))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (buffer text)
                          (with-current-buffer (get-buffer-create buffer)
                            (save-excursion (goto-char (point-max)) (insert text)))
                          (format "Appended text to buffer %s" buffer))
              :name "append_to_buffer" :description "Append text to an Emacs buffer. If the buffer does not exist, it will be created."
              :args (list '(:name "buffer" :type string :description "The name of the buffer to append text to.")
                          '(:name "text" :type string :description "The text to append to the buffer."))
              :category "emacs"))

(add-to-list 'gptel-tools
             (gptel-make-tool :name "EditBuffer" :function #'gptel-edit-buffer
                              :description "Edits Emacs buffers"
                              :args '((:name "buffer_name" :type string :description "Name of the buffer to modify")
                                      (:name "old_string" :type string :description "Text to replace (must match exactly)")
                                      (:name "new_string" :type string :description "Text to replace old_string with"))
                              :category "edit"))

(add-to-list 'gptel-tools
             (gptel-make-tool :name "ReplaceBuffer" :function #'gptel-replace-buffer
                              :description "Completely overwrites buffer contents"
                              :args '((:name "buffer_name" :type string :description "Name of the buffer to overwrite")
                                      (:name "content" :type string :description "Content to write to the buffer"))
                              :category "edit"))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (filepath)
                          (with-temp-buffer
                            (insert-file-contents (expand-file-name filepath))
                            (buffer-string)))
              :name "read_file" :description "Read and display the contents of a file"
              :args (list '(:name "filepath" :type string :description "Path to the file to read. Supports relative paths and ~."))
              :category "filesystem"))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (directory) (mapconcat #'identity (directory-files directory) "\n"))
              :name "list_directory" :description "List the contents of a given directory"
              :args (list '(:name "directory" :type string :description "The path to the directory to list"))
              :category "filesystem"))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (path filename content)
                          (let ((full-path (expand-file-name filename path)))
                            (with-temp-buffer (insert content) (write-file full-path))
                            (format "Created file %s in %s" filename path)))
              :name "create_file" :description "Create a new file with the specified content"
              :args (list '(:name "path" :type string :description "The directory where to create the file")
                          '(:name "filename" :type string :description "The name of the file to create")
                          '(:name "content" :type string :description "The content to write to the file"))
              :category "filesystem"))

(add-to-list 'gptel-tools
             (gptel-make-tool :function #'gptel-edit-file :name "edit_file"
                              :description "Edit file with a list of edits, each edit contains a line-number, old-string and new-string"
                              :args (list '(:name "file-path" :type string :description "The full path of the file to edit")
                                          '(:name "file-edits" :type array
                                                  :items (:type object :properties
                                                                (:line_number (:type integer :description "The line number of the file where edit starts.")
                                                                              :old_string (:type string :description "The old-string to be replaced.")
                                                                              :new_string (:type string :description "The new-string to replace old-string.")))
                                                  :description "The list of edits to apply on the file"))
                              :category "filesystem"))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (command &optional working_dir)
                          (with-temp-message (format "Executing command: `%s`" command)
                            (let ((default-directory (if (and working_dir (not (string= working_dir "")))
                                                         (expand-file-name working_dir) default-directory)))
                              (shell-command-to-string command))))
              :name "run_command" :description "Executes a shell command and returns the output as a string"
              :args (list '(:name "command" :type string :description "The complete shell command to execute.")
                          '(:name "working_dir" :type string :description "Optional: The directory in which to run the command"))
              :category "command" :confirm t :include t))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (text) (message "%s" text) (format "Message sent: %s" text))
              :name "echo_message" :description "Send a message to the *Messages* buffer"
              :args (list '(:name "text" :type string :description "The text to send to the messages buffer"))
              :category "emacs"))

(add-to-list 'gptel-tools
             (gptel-make-tool :name "read_documentation" :function #'gptel-read-documentation
                              :description "Read the documentation for a given function or variable"
                              :args (list '(:name "name" :type string :description "The name of the function or variable whose documentation is to be retrieved"))
                              :category "emacs"))

(add-to-list 'gptel-tools
             (gptel-make-tool
              :function (lambda (url)
                          (with-current-buffer (url-retrieve-synchronously url)
                            (goto-char (point-min)) (forward-paragraph)
                            (let ((dom (libxml-parse-html-region (point) (point-max))))
                              (run-at-time 0 nil #'kill-buffer (current-buffer))
                              (with-temp-buffer (shr-insert-document dom)
                                                (buffer-substring-no-properties (point-min) (point-max))))))
              :name "read_url" :description "Fetch and read the contents of a URL"
              :args (list '(:name "url" :type string :description "The URL to read"))
              :category "web"))

(provide 'gptel-tools)
;;; gptel-tools.el ends here
