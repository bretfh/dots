(in-package :pine.ts)

;;;; CFFI bindings to libtree-sitter. tree-sitter passes TSNode (and
;;;; TSQueryCapture, which embeds one) by value; cffi-libffi handles the
;;;; by-value structs, so no C wrapper is needed. The context[4] array in
;;;; TSNode is flattened to four scalars because CFFI has no by-value
;;;; translation for an array struct member; the fields are never read from
;;;; Lisp, only passed back to ts_node_*.

(cffi:define-foreign-library libtree-sitter
  (t (:default "libtree-sitter")))

(cffi:defcstruct ts-node
  (c0 :uint32) (c1 :uint32) (c2 :uint32) (c3 :uint32)
  (id :pointer) (tree :pointer))

(cffi:defcstruct ts-query-capture
  (c0 :uint32) (c1 :uint32) (c2 :uint32) (c3 :uint32)
  (id :pointer) (tree :pointer)
  (index :uint32))

(cffi:defcstruct ts-query-match
  (id :uint32) (pattern-index :uint16) (capture-count :uint16)
  (captures :pointer))

(cffi:defcfun ("ts_parser_new" ts-parser-new) :pointer)
(cffi:defcfun ("ts_parser_delete" ts-parser-delete) :void (parser :pointer))
(cffi:defcfun ("ts_parser_set_language" ts-parser-set-language) :bool
  (parser :pointer) (language :pointer))
(cffi:defcfun ("ts_parser_parse_string" ts-parser-parse-string) :pointer
  (parser :pointer) (old-tree :pointer) (string :pointer) (length :uint32))
(cffi:defcfun ("ts_tree_delete" ts-tree-delete) :void (tree :pointer))
(cffi:defcfun ("ts_tree_root_node" ts-tree-root-node) (:struct ts-node)
  (tree :pointer))
(cffi:defcfun ("ts_node_start_byte" ts-node-start-byte) :uint32
  (node (:struct ts-node)))
(cffi:defcfun ("ts_node_end_byte" ts-node-end-byte) :uint32
  (node (:struct ts-node)))
(cffi:defcfun ("ts_node_parent" ts-node-parent) (:struct ts-node)
  (node (:struct ts-node)))
(cffi:defcfun ("ts_node_is_null" ts-node-is-null) :bool
  (node (:struct ts-node)))
(cffi:defcfun ("ts_node_named_child_count" ts-node-named-child-count) :uint32
  (node (:struct ts-node)))
(cffi:defcfun ("ts_node_named_child" ts-node-named-child) (:struct ts-node)
  (node (:struct ts-node)) (index :uint32))
(cffi:defcfun ("ts_node_named_descendant_for_byte_range"
               ts-node-named-descendant-for-byte-range) (:struct ts-node)
  (node (:struct ts-node)) (start :uint32) (end :uint32))
(cffi:defcfun ("ts_query_new" ts-query-new) :pointer
  (language :pointer) (source :pointer) (length :uint32)
  (error-offset :pointer) (error-type :pointer))
(cffi:defcfun ("ts_query_delete" ts-query-delete) :void (query :pointer))
(cffi:defcfun ("ts_query_capture_count" ts-query-capture-count) :uint32
  (query :pointer))
(cffi:defcfun ("ts_query_cursor_new" ts-query-cursor-new) :pointer)
(cffi:defcfun ("ts_query_cursor_delete" ts-query-cursor-delete) :void
  (cursor :pointer))
(cffi:defcfun ("ts_query_cursor_exec" ts-query-cursor-exec) :void
  (cursor :pointer) (query :pointer) (node (:struct ts-node)))
(cffi:defcfun ("ts_query_cursor_next_capture" ts-query-cursor-next-capture) :bool
  (cursor :pointer) (match :pointer) (capture-index :pointer))
(cffi:defcfun ("ts_query_capture_name_for_id" ts-query-capture-name-for-id) :pointer
  (query :pointer) (id :uint32) (length :pointer))


;;;; Grammar registry. Each language maps to a grammar shared library, the
;;;; C function that returns its TSLanguage*, and pine's highlight query.
;;;; Grammar libraries come from Guix (on the load path by name); query files
;;;; ship with pine under queries/.

(defparameter *grammars*
  '((:commonlisp "libtree-sitter-commonlisp" "tree_sitter_commonlisp"
     "queries/commonlisp/highlights.scm")
    (:scheme "libtree-sitter-scheme" "tree_sitter_scheme"
     "queries/scheme/highlights.scm")))


;;;; Runtime + per-language entries

(defclass ts-runtime ()
  ((libs-loaded :accessor libs-loaded :initform nil)
   (languages   :accessor languages   :initform (make-hash-table :test 'eq))))

(defclass ts-entry ()
  ((parser        :initarg :parser        :accessor entry-parser)
   (query         :initarg :query         :accessor entry-query)
   (capture-cache :initarg :capture-cache :accessor entry-capture-cache)))

(defun make-ts-runtime () (make-instance 'ts-runtime))
(defun ts-loaded-p (runtime) (libs-loaded runtime))

(defun ensure-ts (runtime)
  (unless (libs-loaded runtime)
    (handler-case
        (progn (cffi:load-foreign-library 'libtree-sitter)
               (setf (libs-loaded runtime) t))
      (error () nil)))
  runtime)

(defun grammar-library-candidates (library-name)
  "Places a grammar shared library may live: the loader's search path (Guix
puts grammars under lib/tree-sitter/, not lib/) and pine's own tree."
  (let ((so (concatenate 'string library-name ".so"))
        (env (sb-ext:posix-getenv "GUIX_ENVIRONMENT")))
    (remove nil
            (list (list :default library-name)
                  (when env (format nil "~a/lib/tree-sitter/~a" env so))
                  (format nil "~alib/tree-sitter/~a"
                          (namestring (asdf:system-source-directory :pine)) so)))))

(defun load-grammar-library (library-name)
  (loop for candidate in (grammar-library-candidates library-name)
        thereis (ignore-errors (cffi:load-foreign-library candidate))))

(defun grammar-language-pointer (library-name fn-name)
  "Load grammar LIBRARY-NAME and call FN-NAME to get its TSLanguage*, or nil."
  (handler-case
      (when (load-grammar-library library-name)
        (let ((fn (cffi:foreign-symbol-pointer fn-name)))
          (when fn (cffi:foreign-funcall-pointer fn () :pointer))))
    (error () nil)))

(defun query-source (relpath)
  (let ((path (merge-pathnames relpath (asdf:system-source-directory :pine))))
    (with-open-file (s path :if-does-not-exist nil)
      (when s
        (let ((str (make-string (file-length s))))
          (subseq str 0 (read-sequence str s)))))))

(defun build-capture-name-cache (query)
  "Cache capture id -> name for the QUERY's captures."
  (let* ((count (ts-query-capture-count query))
         (names (make-array count)))
    (dotimes (i count)
      (cffi:with-foreign-object (len :uint32)
        (let ((p (ts-query-capture-name-for-id query i len)))
          (setf (aref names i)
                (if (cffi:null-pointer-p p)
                    ""
                    (cffi:foreign-string-to-lisp p :count (cffi:mem-ref len :uint32)))))))
    names))

(defun load-language-entry (language)
  (destructuring-bind (&optional library fn-name query-relpath)
      (cdr (assoc language *grammars*))
    (unless library (return-from load-language-entry nil))
    (let ((lang (grammar-language-pointer library fn-name)))
      (when (and lang (not (cffi:null-pointer-p lang)))
        (let ((parser (ts-parser-new)))
          (ts-parser-set-language parser lang)
          (let ((query-text (query-source query-relpath)))
            (unless query-text
              (ts-parser-delete parser)
              (return-from load-language-entry nil))
            (cffi:with-foreign-objects ((err-offset :uint32) (err-type :uint32))
              (cffi:with-foreign-string (src query-text)
                (let ((query (ts-query-new lang src (length query-text)
                                           err-offset err-type)))
                  (if (cffi:null-pointer-p query)
                      (progn (ts-parser-delete parser) nil)
                      (make-instance 'ts-entry
                                     :parser parser :query query
                                     :capture-cache (build-capture-name-cache query))))))))))))

(defun ensure-language (runtime language)
  "Return LANGUAGE's ts-entry, loading it once, or nil if unsupported."
  (unless (libs-loaded runtime) (ensure-ts runtime))
  (unless (libs-loaded runtime) (return-from ensure-language nil))
  (or (gethash language (languages runtime))
      (let ((entry (load-language-entry language)))
        (when entry (setf (gethash language (languages runtime)) entry)))))


;;;; Face mapping (portable)

(defvar *cl-special-forms* (make-hash-table :test 'equal))

(dolist (sym '("block" "catch" "eval-when" "flet" "function" "go" "if"
               "labels" "let" "let*" "load-time-value" "locally" "macrolet"
               "multiple-value-call" "multiple-value-prog1" "progn" "progv"
               "quote" "return-from" "setq" "symbol-macrolet" "tagbody"
               "the" "throw" "unwind-protect"
               "defvar" "defparameter" "defconstant" "defstruct" "defclass"
               "deftype" "defsetf" "define-setf-expander"
               "define-symbol-macro" "define-compiler-macro"
               "define-condition" "define-modify-macro"
               "define-method-combination"
               "defpackage" "in-package" "use-package"
               "declaim" "declare" "proclaim"
               "cond" "when" "unless" "case" "ecase" "ccase" "typecase"
               "etypecase" "ctypecase"
               "do" "do*" "dolist" "dotimes" "loop"
               "and" "or" "not"
               "with-open-file" "with-open-stream" "with-input-from-string"
               "with-output-to-string" "with-accessors" "with-slots"
               "with-standard-io-syntax" "with-compilation-unit"
               "with-condition-restarts" "with-hash-table-iterator"
               "with-package-iterator" "with-simple-restart"
               "handler-case" "handler-bind" "restart-case" "restart-bind"
               "ignore-errors"
               "destructuring-bind" "multiple-value-bind" "multiple-value-setq"
               "multiple-value-list"
               "prog" "prog*" "prog1" "prog2"
               "return" "return-from"
               "setf" "psetf" "psetq" "rotatef" "shiftf"
               "push" "pop" "pushnew" "remf"
               "incf" "decf"
               "assert" "check-type"
               "trace" "untrace" "step"
               "time" "inspect"
               "export" "import" "intern" "shadow" "shadowing-import"
               "provide" "require"
               "defmethod" "defgeneric"
               "lambda"))
  (setf (gethash sym *cl-special-forms*) t))

(defvar *cl-constants* (make-hash-table :test 'equal))

(dolist (sym '("t" "nil" "pi"
               "most-positive-fixnum" "most-negative-fixnum"
               "most-positive-double-float" "most-negative-double-float"
               "most-positive-single-float" "most-negative-single-float"
               "most-positive-short-float" "most-negative-short-float"
               "most-positive-long-float" "most-negative-long-float"))
  (setf (gethash sym *cl-constants*) t))

(defun capture-name-to-face (name)
  (cond
    ((or (string= name "comment") (string= name "comment.block")) :comment)
    ((or (string= name "string") (string= name "path")) :string)
    ((or (string= name "character") (string= name "string.escape")) :escape)
    ((or (string= name "number") (string= name "constant")) :constant)
    ((string= name "constant.builtin") :constant)
    ((or (string= name "keyword") (string= name "keyword.function")) :keyword)
    ((or (string= name "function") (string= name "function.call")
         (string= name "function.definition")) :function-name)
    ((or (string= name "function.builtin") (string= name "operator")
         (string= name "variable.builtin")) :builtin)
    ((string= name "variable.parameter") :variable-param)
    ((string= name "variable") :variable)
    ((string= name "type") :type)
    (t nil)))

(defun reclassify (face text start end)
  (when (or (eq face :function-name) (eq face :variable))
    (let ((sym (string-downcase (subseq text
                                        (min start (length text))
                                        (min end (length text))))))
      (cond
        ((and (eq face :function-name) (gethash sym *cl-special-forms*))
         (return-from reclassify :keyword))
        ((and (eq face :variable) (gethash sym *cl-constants*))
         (return-from reclassify :constant)))))
  face)


;;;; Highlight computation (portable)

(defun char-byte-length (ch)
  "UTF-8 encoded length in bytes of the single character CH."
  (let ((code (char-code ch)))
    (cond ((< code #x80) 1) ((< code #x800) 2) ((< code #x10000) 3) (t 4))))

(defun build-line-index (text)
  "Vector of (start-byte . start-char) per line. tree-sitter reports positions
in UTF-8 bytes while the cell grid and point are in characters; the index
converts both ways without assuming one byte per character."
  (let ((index (list (cons 0 0))) (bpos 0) (ci 0))
    (loop for ch across text
          do (incf bpos (char-byte-length ch))
             (incf ci)
             (when (char= ch #\Newline) (push (cons bpos ci) index)))
    (coerce (nreverse index) 'vector)))

(defun %line-of-byte (byte-pos index)
  "Greatest line whose start byte is <= BYTE-POS."
  (let ((lo 0) (hi (1- (length index))))
    (loop while (< lo hi)
          do (let ((mid (ceiling (+ lo hi) 2)))
               (if (<= (car (aref index mid)) byte-pos)
                   (setf lo mid)
                   (setf hi (1- mid)))))
    lo))

(defun byte-to-line-col (byte-pos index text)
  "Map a UTF-8 BYTE-POS to (values line char-col) using the line INDEX and TEXT."
  (let* ((line (%line-of-byte byte-pos index))
         (b (car (aref index line)))
         (ci (cdr (aref index line)))
         (len (length text))
         (col 0))
    (loop while (and (< b byte-pos) (< ci len))
          do (incf b (char-byte-length (char text ci)))
             (incf ci)
             (incf col))
    (values line col)))

(defun byte-length (text)
  (length (sb-ext:string-to-octets text :external-format :utf-8)))

(defun collect-captures (cursor query cache text index)
  "Iterate CURSOR's captures, mapping each to (line start-col end-col face)."
  (let ((highlights nil))
    (cffi:with-foreign-objects ((match '(:struct ts-query-match))
                                (cap-index :uint32))
      (loop
        (unless (ts-query-cursor-next-capture cursor match cap-index) (return))
        (let* ((ci (cffi:mem-ref cap-index :uint32))
               (caps (cffi:foreign-slot-value match '(:struct ts-query-match) 'captures))
               (cap (cffi:mem-aptr caps '(:struct ts-query-capture) ci))
               (idx (cffi:foreign-slot-value cap '(:struct ts-query-capture) 'index))
               (node (cffi:mem-ref cap '(:struct ts-node)))
               (name (if (< idx (length cache)) (aref cache idx) ""))
               (raw (capture-name-to-face name)))
          (when raw
            (let* ((start (ts-node-start-byte node))
                   (end (ts-node-end-byte node))
                   (face (reclassify raw text start end)))
              (when face
                (multiple-value-bind (sl sc) (byte-to-line-col start index text)
                  (multiple-value-bind (el ec) (byte-to-line-col end index text)
                    (if (= sl el)
                        (push (list sl sc ec face) highlights)
                        (progn
                          (push (list sl sc 999 face) highlights)
                          (loop for l from (1+ sl) below el
                                do (push (list l 0 999 face) highlights))
                          (push (list el 0 ec face) highlights)))))))))))
    highlights))

(defun compute-highlights (runtime language text)
  (let ((entry (ensure-language runtime language)))
    (unless entry (return-from compute-highlights nil))
    (let ((parser (entry-parser entry))
          (query  (entry-query entry))
          (cache  (entry-capture-cache entry))
          (line-index (build-line-index text))
          (highlights nil))
      (handler-case
          (cffi:with-foreign-string (cstr text :encoding :utf-8)
            (let ((tree (ts-parser-parse-string parser (cffi:null-pointer)
                                                cstr (byte-length text))))
              (when (and tree (not (cffi:null-pointer-p tree)))
                (unwind-protect
                     (let ((cursor (ts-query-cursor-new))
                           (root (ts-tree-root-node tree)))
                       (unwind-protect
                            (progn
                              (ts-query-cursor-exec cursor query root)
                              (setf highlights
                                    (collect-captures cursor query cache text line-index)))
                         (ts-query-cursor-delete cursor)))
                  (ts-tree-delete tree)))))
        (error () nil))
      (nreverse highlights))))


;;;; Structural navigation. Each motion parses the buffer, walks the tree once,
;;;; and returns a target position; the tree lives only for the call.

(defun call-with-root (runtime language text fn)
  "Parse TEXT and call FN with the tree's root node. Returns FN's values, or nil."
  (let ((entry (ensure-language runtime language)))
    (when entry
      (handler-case
          (cffi:with-foreign-string (cstr text :encoding :utf-8)
            (let ((tree (ts-parser-parse-string (entry-parser entry)
                                                (cffi:null-pointer) cstr
                                                (byte-length text))))
              (when (and tree (not (cffi:null-pointer-p tree)))
                (unwind-protect (funcall fn (ts-tree-root-node tree))
                  (ts-tree-delete tree)))))
        (error () nil)))))

(defun pos-to-byte (text line col index)
  "UTF-8 byte offset of the character position LINE/COL."
  (let* ((line (min line (1- (length index))))
         (bpos (car (aref index line)))
         (ci (cdr (aref index line)))
         (len (length text)))
    (loop for k from 0 below col
          while (< ci len)
          do (incf bpos (char-byte-length (char text ci)))
             (incf ci))
    bpos))

(defun %forward-sexp-byte (root byte)
  (let ((cur (ts-node-named-descendant-for-byte-range root byte byte)))
    (cond
      ((ts-node-is-null cur) nil)
      ((<= byte (ts-node-start-byte cur)) (ts-node-end-byte cur))
      (t (loop for i from 0 below (ts-node-named-child-count cur)
               for child = (ts-node-named-child cur i)
               when (>= (ts-node-start-byte child) byte)
                 return (ts-node-end-byte child)
               finally (return (ts-node-end-byte cur)))))))

(defun %backward-sexp-byte (root byte)
  (let ((cur (ts-node-named-descendant-for-byte-range root byte byte)))
    (cond
      ((ts-node-is-null cur) nil)
      ((>= byte (ts-node-end-byte cur)) (ts-node-start-byte cur))
      (t (loop for i from (1- (ts-node-named-child-count cur)) downto 0
               for child = (ts-node-named-child cur i)
               when (<= (ts-node-end-byte child) byte)
                 return (ts-node-start-byte child)
               finally (return (ts-node-start-byte cur)))))))

(defun %defun-bytes (root byte)
  "Start and end bytes of the top-level form (a direct child of ROOT)
containing BYTE, or nil."
  (let ((cur (ts-node-named-descendant-for-byte-range root byte byte)))
    (cond
      ((ts-node-is-null cur) nil)
      ;; Climb until CUR's parent is ROOT (i.e. its grandparent is null),
      ;; leaving CUR as the enclosing top-level form -- not ROOT itself.
      (t (loop for p = (ts-node-parent cur)
               until (or (ts-node-is-null p) (ts-node-is-null (ts-node-parent p)))
               do (setf cur p))
         (values (ts-node-start-byte cur) (ts-node-end-byte cur))))))

(defun forward-sexp-pos (runtime language text line col)
  "Position (values line col) after the next sexp, or nil."
  (let* ((index (build-line-index text))
         (byte (pos-to-byte text line col index))
         (target (call-with-root runtime language text
                                 (lambda (root) (%forward-sexp-byte root byte)))))
    (when target (byte-to-line-col target index text))))

(defun backward-sexp-pos (runtime language text line col)
  (let* ((index (build-line-index text))
         (byte (pos-to-byte text line col index))
         (target (call-with-root runtime language text
                                 (lambda (root) (%backward-sexp-byte root byte)))))
    (when target (byte-to-line-col target index text))))

(defun defun-bounds-pos (runtime language text line col)
  "Bounds of the enclosing top-level form as (values start-line start-col
end-line end-col), or nil."
  (let* ((index (build-line-index text))
         (byte (pos-to-byte text line col index)))
    (multiple-value-bind (start end)
        (call-with-root runtime language text
                        (lambda (root) (%defun-bytes root byte)))
      (when start
        (multiple-value-bind (sl sc) (byte-to-line-col start index text)
          (multiple-value-bind (el ec) (byte-to-line-col end index text)
            (values sl sc el ec)))))))
