(in-package :pine.actor)

(defstruct agent-info
  name type actor meta port)

(defun start-agent-registry (server)
  (let ((sys (pine.server:actor-system server)))
    (setf (pine.server:agent-registry server)
          (ac:actor-of sys
            :name "agent-registry"
            :state (make-hash-table :test 'equal)
            :receive
            (lambda (msg)
              (case (first msg)
                (:register
                 (destructuring-bind (&key info) (rest msg)
                   (setf (gethash (agent-info-name info) act:*state*) info)
                   (reply info)))
                (:register-remote
                 (destructuring-bind (&key name host port) (rest msg)
                   (let* ((uri (format nil "sento://~a:~d/user/agent" host port))
                          (ref (rem:make-remote-ref sys uri))
                          (info (make-agent-info :name name :type :process
                                                 :actor ref :port port)))
                     (setf (gethash name act:*state*) info)
                     (reply info))))
                (:unregister
                 (destructuring-bind (&key name) (rest msg)
                   (remhash name act:*state*)
                   (reply t)))
                (:lookup
                 (destructuring-bind (&key name) (rest msg)
                   (reply (gethash name act:*state*))))
                (:list
                 (let ((agents nil))
                   (maphash (lambda (k v) (declare (ignore k)) (push v agents))
                            act:*state*)
                   (reply (nreverse agents))))
                (t (reply (list :error :unknown msg)))))))))

(defun register-agent (server name type actor &key meta port)
  (act:ask-s (pine.server:agent-registry server)
             (list :register :info (make-agent-info :name name :type type
                                                    :actor actor :meta meta :port port))
             :time-out 5))

(defun unregister-agent (server name)
  (act:ask-s (pine.server:agent-registry server) (list :unregister :name name) :time-out 5))

(defun find-agent (server name)
  (act:ask-s (pine.server:agent-registry server) (list :lookup :name name) :time-out 5))

(defun list-agents (server)
  (act:ask-s (pine.server:agent-registry server) '(:list) :time-out 5))

(defun resolve-agent (server agent-or-name)
  "The actor ref for AGENT-OR-NAME (an agent-info, a registered name, or a ref)."
  (etypecase agent-or-name
    (agent-info (agent-info-actor agent-or-name))
    (string (let ((info (find-agent server agent-or-name)))
              (unless info (error "No agent named ~s" agent-or-name))
              (agent-info-actor info)))
    (t agent-or-name)))

(defun agent-eval (server agent-or-name form-string &key on-done package bindings)
  "Evaluate FORM-STRING in AGENT-OR-NAME through pine.eval, off the agent's
mailbox thread. Returns immediately; the result reaches ON-DONE and any error
reaches the shared debugger surface."
  (act:tell (resolve-agent server agent-or-name)
            (list :eval :form form-string :package package
                  :bindings bindings :on-done on-done)))

(defun agent-compile (server agent-or-name text &key on-done package bindings)
  (act:tell (resolve-agent server agent-or-name)
            (list :compile :text text :package package
                  :bindings bindings :on-done on-done)))


(defun start-local-agent (server)
  (let* ((sys (pine.server:actor-system server))
         (local (ac:actor-of sys
                  :name "local-agent"
                  :receive
                  (lambda (msg)
                    (case (first msg)
                      ;; Evaluation runs through pine.eval on its own thread, so
                      ;; a looping or erroring form can neither block this actor's
                      ;; mailbox (and the shared dispatcher behind it) nor drop to
                      ;; a console debugger. Fire-and-forget: the result reaches
                      ;; ON-DONE and errors reach the shared *on-debug* surface,
                      ;; not a synchronous reply.
                      ((:eval :compile)
                       (destructuring-bind (&key form text package bindings on-done)
                           (rest msg)
                         (let ((source (or form text)))
                           (when source
                             (pine.eval:evaluate-string
                              source
                              :package (or (and package (find-package package))
                                           (find-package :cl-user))
                              :bindings bindings
                              :on-done on-done)))
                         (reply :started)))
                      (:set-package
                       (destructuring-bind (&key name) (rest msg)
                         (let ((pkg (find-package name)))
                           (if pkg
                               (progn (setf *package* pkg)
                                      (reply (list :ok (package-name pkg))))
                               (reply (list :error (format nil "No package ~s" name)))))))
                      (:ping (reply :pong))
                      (:shutdown (reply :ok))
                      (t (reply (list :error :unknown-message (first msg)))))))))
    (register-agent server "local" :local local)
    local))


(defun spawn-agent (server name)
  (let ((master-port (pine.server:remoting-port server)))
    (unless master-port
      (error "Cannot spawn agent: remoting not enabled."))
    (let* ((script (format nil
                           "(require :asdf)~%(asdf:load-system :pine-agent)~%(pine.agent:connect :name ~s :master-port ~d)~%"
                           name master-port))
           (tmp (merge-pathnames (format nil "pine-agent-~a.lisp" name)
                                 (uiop:temporary-directory))))
      (with-open-file (s tmp :direction :output :if-exists :supersede)
        (write-string script s))
      (uiop:launch-program
       (list "ecl" "-q" "--load"
             (namestring (merge-pathnames "init.lisp"
                                          (asdf:system-source-directory :pine)))
             "--load" (namestring tmp)))
      (loop for i from 0 below 150
            for info = (find-agent server name)
            when info return info
            do (sleep 0.1)
            finally (error "Agent ~s did not connect within 15 seconds." name)))))

(defun kill-agent (server name)
  (let ((info (find-agent server name)))
    (when info
      (handler-case
          (act:ask-s (agent-info-actor info) '(:shutdown) :time-out 5)
        (error () nil))
      (unregister-agent server name))))
