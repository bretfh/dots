(in-package :pine.event)

(defun make-event-bus (server)
  (let ((sys (pine.server:actor-system server)))
    (setf (pine.server:event-bus server)
          (sento.actor-context:actor-of sys
            :name "event-bus"
            :state (make-hash-table :test 'eq)
            :receive
            (lambda (msg)
              (case (first msg)
                (:publish
                 (destructuring-bind (&key topic payload) (rest msg)
                   (let ((handlers (gethash topic sento.actor:*state*)))
                     (loop for fn in handlers do (funcall fn payload)))))
                (:subscribe
                 (destructuring-bind (&key topic handler) (rest msg)
                   (push handler (gethash topic sento.actor:*state*))
                   (sento.actor:reply t)))
                (:unsubscribe
                 (destructuring-bind (&key topic handler) (rest msg)
                   (setf (gethash topic sento.actor:*state*)
                         (remove handler (gethash topic sento.actor:*state*)))
                   (sento.actor:reply t)))))))))

(defun publish (bus topic payload)
  (sento.actor:tell bus (list :publish :topic topic :payload payload)))

(defun subscribe (bus topic handler)
  (sento.actor:ask-s bus (list :subscribe :topic topic :handler handler) :time-out 5))

(defun unsubscribe (bus topic handler)
  (sento.actor:ask-s bus (list :unsubscribe :topic topic :handler handler) :time-out 5))
