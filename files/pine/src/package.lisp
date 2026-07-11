(defpackage :pine.server
  (:use :cl)
  (:export
   #:server
   #:actor-system
   #:event-bus
   #:agent-registry
   #:buffer-registry
   #:layouts
   #:buffer-table
   #:commands
   #:global-keymap
   #:faces
   #:ts-runtime
   #:modes
   #:clients
   #:remoting-port
   #:start-server
   #:stop-server))

(defpackage :pine.actor
  (:use :cl :ac :act :asys :rem)
  (:export
   #:agent-info
   #:agent-info-name #:agent-info-type #:agent-info-actor
   #:agent-info-meta #:agent-info-port
   #:start-agent-registry
   #:register-agent #:unregister-agent #:find-agent #:list-agents
   #:agent-eval #:agent-compile
   #:start-local-agent
   #:spawn-agent #:kill-agent))

(defpackage :pine.event
  (:use :cl)
  (:export
   #:make-event-bus
   #:publish
   #:subscribe
   #:unsubscribe))

(defpackage :pine.hooks
  (:use :cl)
  (:export
   #:add-init-hook
   #:add-shutdown-hook
   #:run-init-hooks
   #:run-shutdown-hooks))

(defpackage :pine.buffer
  (:use :cl)
  (:export
   ;; buffer-state
   #:buffer-state #:lines #:marks #:meta #:tick
   ;; snapshot
   #:snapshot #:name #:line-count #:point-line #:point-col #:highlights
   ;; state ops
   #:make-empty-state #:state->snapshot #:state->snapshot-with-hl #:state->string
   #:insert-char #:insert-string #:insert-newline
   #:delete-char #:delete-region
   #:move-mark #:set-meta
   #:buffer-local
   #:load-content #:notify-subscribers
   #:line-count-of #:line-at #:region-string
   ;; faces
   #:face #:fg #:bg #:bold #:italic #:underline
   #:defface #:find-face #:face-to-plist #:install-default-faces
   #:face-run #:run-start #:run-end #:run-face
   #:display-line #:display-text #:display-runs
   #:make-display-line #:display-line-to-plist
   ;; windows
   #:window #:buffer-ref #:window-name #:row #:col #:win-width #:win-height
   #:scroll-top #:focusedp #:snap #:win-display
   #:frame #:windows #:frame-cols #:frame-rows #:bg-face
   #:frame-cells #:frame-cell-count #:frame-cursor-row #:frame-cursor-col
   #:frame-scroll-pixel #:frame-dirtyp #:ensure-frame-cells
   #:make-window #:remove-window #:focus-window
   #:window-display-lines #:ensure-point-visible #:ensure-col-visible
   #:build-frame #:frame-to-plist
   ;; buffer actor
   #:make-buffer-actor #:notify-subscribers #:load-content
   ;; registry
   #:start-buffer-registry
   #:make-buffer #:kill-buffer #:switch-buffer
   #:list-buffers #:buffer-count
   #:current-buffer-text #:current-buffer-snapshot
   ;; high-level API
   #:buffer #:ask #:tell))

(defpackage :pine.echo
  (:use :cl)
  (:export #:message #:current-message
           #:show-input #:hide-input
           #:input-active-p #:input-prompt #:input-text #:set-input-text
           #:show-completions-area #:hide-completions-area #:completions-text))

(defpackage :pine.file
  (:use :cl)
  (:export
   #:read-file
   #:write-file
   #:find-file
   #:save-current-buffer))

(defpackage :pine.render
  (:use :cl)
  (:export
   #:ts-request-parse
   #:start-renderer
   #:start-ts-actor
   #:subscribe-to-buffer
   #:unsubscribe-from-buffer
   #:render-buffer-to-frame
   #:relayout))

(defpackage :pine.repl
  (:use :cl)
  (:export
   #:start-repl
   #:repl-eval
   #:repl-submit
   #:repl-buffer))

(defpackage :pine.ts
  (:use :cl)
  (:export
   #:ts-runtime
   #:make-ts-runtime
   #:ts-loaded-p
   #:ensure-ts
   #:ensure-language
   #:compute-highlights
   #:capture-name-to-face
   #:forward-sexp-pos
   #:backward-sexp-pos
   #:defun-bounds-pos))

(defpackage :pine.term
  (:use :cl)
  (:export
   #:terminal #:terminal-term #:terminal-fd #:terminal-pid #:terminal-buffer
   #:open-terminal
   #:terminal-for-buffer
   #:term-write
   #:gterm-text
   #:drain-terminals
   #:resize-active-terminal
   #:terminal-dispatch))

(defpackage :pine.mode
  (:use :cl)
  (:export
   #:mode #:major-mode #:minor-mode
   #:base-mode #:text-mode #:lisp-mode #:repl-mode #:terminal-mode
   #:overwrite-mode
   #:mode-name #:mode-keymap #:mode-indicator #:parent-mode #:ts-language
   #:precedence #:transparent
   #:register-mode #:find-mode #:global-keymap
   #:buffer-mode #:current-buffer-mode #:set-buffer-mode #:mode-for-file
   #:buffer-active-modes #:buffer-minor-modes #:active-keymaps
   #:active-modes-instance
   #:minor-mode-enabled-p #:enable-minor-mode #:disable-minor-mode
   #:toggle-minor-mode #:active-minor-mode-indicators
   #:dispatch-message #:install-default-modes))

(defpackage :pine.var
  (:use :cl)
  (:export
   #:evar #:define-variable #:find-variable #:all-variable-names
   #:variable-value #:variable-scope #:set-variable #:set-global #:set-buffer-local
   #:evar-name #:evar-default #:evar-documentation #:evar-global #:evar-global-set))

(defpackage :pine.layout
  (:use :cl)
  (:export
   ;; nodes
   #:node #:key-of #:parent #:face #:hint #:expand-of
   #:start-line #:start-col #:end-line #:end-col
   #:text-node #:content
   #:separator #:sep-char
   #:spacer #:center
   #:scroll #:scroll-offset #:vheight
   #:field #:prefix-length
   #:input-start-line #:input-start-col #:input-end-line #:input-end-col
   #:vstack #:children #:spacing #:align
   #:hstack
   #:box #:child #:width-of #:pad-char
   #:selectable #:data #:selectedp #:prefix-selected #:prefix-unselected
   #:action #:callback
   #:list-node #:items #:item-fn #:max-visible
   #:grid #:cells #:col-widths
   #:slider #:value #:min-of #:max-of #:track #:on-change #:filled-face #:empty-face
   ;; constructor DSL
   #:label #:icon #:column #:row #:button #:boxed #:centered #:viewport
   #:gap #:rule #:meter #:rows #:choice
   ;; layout protocol
   #:measure #:arrange #:paint
   ;; layout container
   #:layout #:layout-root #:layout-buffer-name #:layout-state #:layout-width #:layout-height
   #:install-layout #:uninstall-layout #:buffer-layout #:layout-get
   #:defwidget
   #:render-layout #:render-layout-grid #:layout-lines #:node-to-string
   ;; input
   #:input-string #:cursor-offset
   #:type-char-at-cursor #:delete-char-before-cursor
   #:kill-input #:kill-to-end #:kill-word-before-cursor
   #:set-input #:move-cursor #:cursor-to-start #:cursor-to-end
   #:confirm-input
   ;; hit-testing + selection
   #:node-at #:action-at #:click-thunk #:slider-value-at #:hint-at
   #:collect-selectables #:update-selection #:selected-node #:selection-move
   #:scroll-to-selection))

(defpackage :pine.client
  (:use :cl)
  (:export
   #:client
   #:completion
   #:actor
   #:renderer
   #:ts-actor
   #:render-state
   #:frame
   #:windows
   #:focused-window
   #:pending-keys
   #:prefix-arg
   #:this-command-key
   #:pending-key-reader
   #:mode-stack
   #:completion-state
   #:current-buffer
   #:buffer-modes
   #:buffer-minor-modes
   #:kill-ring
   #:kill-ring-max
   #:last-command
   #:server-of
   #:terminals
   #:terminal-map
   #:repl-buffer
   #:prompt-callback
   #:prompt-active
   #:active-p
   #:candidates
   #:filtered
   #:index
   #:input
   #:callback
   #:prompt
   #:dynamic-fn
   #:*client*
   #:current-client
   #:start-client
   #:stop-client))

(defpackage :pine.editor
  (:use :cl)
  (:export
   #:start-editor
   #:install-commands
   #:install-bindings
   #:focused-snap
   #:scroll-window
   #:eval-last-sexp
   #:eval-buffer
   #:on-minibuffer-accept
   ;; prompt
   #:prompt
   #:cancel-prompt
   ;; kill ring
   #:kill-ring-push
   #:kill-ring-top
   #:set-mark
   #:region-bounds
   #:kill-region-cmd
   #:kill-line-cmd
   #:copy-region-cmd
   #:yank-cmd
   #:yank-pop-cmd
   ;; completing-read
   #:completing-read
   #:read-file-name
   #:file-completion-active-p
   #:file-name-complete
   #:file-name-accept
   #:completion-accept
   #:completion-cancel
   #:completion-next
   #:completion-prev
   #:completion-update-input
   #:completing-read-active-p))

(defpackage :pine
  (:use :cl)
  (:export
   #:main
   #:stop
   #:*version*
   #:*target*
   #:desktop?
   #:mobile?
   #:on-minibuffer-accept))
