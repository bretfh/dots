(in-package :pine.client)

(defclass completion ()
  ((active-p   :initarg :active-p   :accessor active-p   :initform nil)
   (candidates :initarg :candidates :accessor candidates :initform nil)
   (filtered   :initarg :filtered   :accessor filtered   :initform nil)
   (index      :initarg :index      :accessor index      :initform -1)
   (input      :initarg :input      :accessor input      :initform "")
   (callback   :initarg :callback   :accessor callback   :initform nil)
   (prompt     :initarg :prompt     :accessor prompt     :initform "")
   ;; when set, a function of the current input returning fresh candidates
   ;; (filesystem path completion), instead of filtering a fixed list.
   (dynamic-fn :initarg :dynamic-fn :accessor dynamic-fn :initform nil)))

(defclass client ()
  ((server-of       :initarg :server-of       :accessor server-of       :initform nil)
   (actor           :initarg :actor           :accessor actor           :initform nil)
   (renderer        :initarg :renderer        :accessor renderer        :initform nil)
   (ts-actor        :initarg :ts-actor        :accessor ts-actor        :initform nil)
   (render-state    :initarg :render-state    :accessor render-state
                    :initform (fset:map (:dirty nil)))
   (frame           :initarg :frame           :accessor frame           :initform nil)
   (windows         :initarg :windows         :accessor windows         :initform nil)
   (focused-window  :initarg :focused-window  :accessor focused-window  :initform nil)
   (pending-keys    :initarg :pending-keys    :accessor pending-keys    :initform nil)
   (prefix-arg      :initarg :prefix-arg      :accessor prefix-arg      :initform nil)
   (this-command-key :initarg :this-command-key :accessor this-command-key :initform nil)
   (pending-key-reader :initarg :pending-key-reader :accessor pending-key-reader
                    :initform nil)
   (mode-stack      :initarg :mode-stack      :accessor mode-stack      :initform nil)
   (completion-state
     :initarg :completion-state :accessor completion-state
     :initform (make-instance 'completion))
   (current-buffer  :initarg :current-buffer  :accessor current-buffer  :initform nil)
   (buffer-modes    :initarg :buffer-modes    :accessor buffer-modes
                    :initform (make-hash-table :test 'eq))
   (buffer-minor-modes :initarg :buffer-minor-modes :accessor buffer-minor-modes
                    :initform (make-hash-table :test 'eq))
   (kill-ring       :initarg :kill-ring       :accessor kill-ring       :initform nil)
   (kill-ring-max   :initarg :kill-ring-max   :accessor kill-ring-max   :initform 60)
   (last-command    :initarg :last-command    :accessor last-command    :initform nil)
   (terminals       :initarg :terminals       :accessor terminals       :initform nil)
   (terminal-map    :initarg :terminal-map    :accessor terminal-map    :initform nil)
   (repl-buffer     :initarg :repl-buffer     :accessor repl-buffer     :initform nil)
   (prompt-callback :initarg :prompt-callback :accessor prompt-callback :initform nil)
   (prompt-active   :initarg :prompt-active   :accessor prompt-active   :initform nil)))

(defvar *client* nil)

(defun current-client ()
  (or *client* (error "No *client* bound.")))

(defun start-client (server)
  (let* ((cli (make-instance 'client
                :server-of server
                :frame (make-instance 'pine.buffer::frame)
                :terminal-map (make-hash-table :test 'eq))))
    (push cli (pine.server:clients server))
    cli))

(defun stop-client (cli)
  (let ((srv (server-of cli)))
    (when srv
      (setf (pine.server:clients srv) (remove cli (pine.server:clients srv)))))
  (when (eq *client* cli)
    (setf *client* nil))
  cli)
