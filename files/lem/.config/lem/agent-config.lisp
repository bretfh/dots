;;; Lem Agent Configuration

(in-package :lem-agent)

;; Default provider
(setf *default-provider* :gemini)

;; API Keys (set these to your actual keys)
;; You can also set these via environment variables:
;; - GEMINI_API_KEY
;; - ANTHROPIC_API_KEY  
;; - OPENAI_API_KEY

;; Example:
;; (set-api-key :gemini "your-gemini-api-key-here")
;; (set-api-key :anthropic "your-anthropic-api-key-here")
;; (set-api-key :openai "your-openai-api-key-here")

;; Debug mode
(setf *debug-mode* nil)

;; Custom keybinding (optional)
;; (define-key lem:*global-keymap* "C-c a" 'lem-agent:start-agent)