(list_lit (sym_lit) @variable)

(comment) @comment
(block_comment) @comment
(dis_expr) @comment

(str_lit) @string
(path_lit) @string
(char_lit) @character
(fancy_literal) @string
(num_lit) @number
(complex_num_lit) @number
(nil_lit) @constant.builtin
(kwd_lit) @constant
(self_referential_reader_macro) @constant

(defun_header
  function_name: (sym_lit) @function)
(defun_header
  function_name: (package_lit) @function)
(defun_header
  specifier: (kwd_lit) @keyword)
(defun_header
  specifier: (sym_lit) @keyword)
(defun_header
  lambda_list: (list_lit (sym_lit) @variable.parameter))
(defun_header
  lambda_list: (list_lit (list_lit . (sym_lit) @variable.parameter)))

(var_quoting_lit
  value: (sym_lit) @function)
(var_quoting_lit
  value: (package_lit) @function)

(loop_keyword) @keyword
(for_clause_word) @keyword
(accumulation_verb) @keyword
(for_clause
  variable: (sym_lit) @variable.parameter)
(for_clause
  variable: (list_lit (sym_lit) @variable.parameter))

(quoting_lit
  value: (sym_lit) @constant)

(list_lit . (sym_lit) @function.call)
(list_lit . (package_lit) @function.call)

(format_specifier) @string.escape
(include_reader_macro) @keyword

(package_lit
  package: (sym_lit) @type)

(defun_keyword) @keyword
