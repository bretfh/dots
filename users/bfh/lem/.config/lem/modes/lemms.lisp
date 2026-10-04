(in-package :arc)

;; Set up default media paths (customize these)
(setf lemms:*playlist-paths* 
      (list #P"~/Music/" 
            #P"~/Downloads/"))

;; Create a shortcut command with a simpler name
(define-command playlist () ()
                "Show the media playlist"
                (lemms:show-playlist))

;; Add global keybinding for quick access
(define-key *global-keymap* "C-c p" 'playlist)

;; Optional: Define key to launch playlist when viewing media files
(define-key *global-keymap* "C-c m" 'play-this-file)

;; Command to play the current file
(define-command play-this-file () ()
                "Play the current file if it's a media file"
                (let ((file (buffer-filename (current-buffer))))
                  (if (and file 
                           (or (lemms:is-audio-p file)
                               (lemms:is-video-p file)))
                      (progn
                        (lemms:ensure-top-level-player)
                        (lemms:play file lemms:*player*)
                        (message "Playing: ~A" (file-namestring file)))
                    (message "Not a media file"))))
