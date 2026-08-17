(in-package :arc)

;; Set up default media paths (customize these)
(setf media-player:*playlist-paths* 
      (list #P"~/Music/" 
            #P"~/Downloads/"))

;; Create a shortcut command with a simpler name
(define-command playlist () ()
                "Show the media playlist"
                (media-player:show-playlist))

;; Add global keybinding for quick access
(define-key *global-keymap* "C-c p" 'playlist)

;; Optional: Define key to launch playlist when viewing media files
(define-key *global-keymap* "C-c m" 'play-this-file)

;; Command to play the current file
(define-command play-this-file () ()
                "Play the current file if it's a media file"
                (let ((file (buffer-filename (current-buffer))))
                  (if (and file 
                           (or (media-player:is-audio-p file)
                               (media-player:is-video-p file)))
                      (progn
                        (media-player:ensure-top-level-player)
                        (media-player:play file media-player:*player*)
                        (message "Playing: ~A" (file-namestring file)))
                    (message "Not a media file"))))
