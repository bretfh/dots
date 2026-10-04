;; -*- lexical-binding: t -*-

(use-package emms-setup
  :init
  (add-hook 'emms-player-started-hook 'emms-show)
  (setq emms-show-format "Playing: %s")
  :config
  (emms-all)
  (setq emms-player-list '(emms-player-mpv))
  ;; look into tinytag for metadata extraction
  ;;(setq emms-browser-covers 'emms-browser-cache-thumbnail-async)
  (setq emms-player-mpv-parameters '("--quiet" "--really-quiet" "--no-config" "--save-position-on-quit" "--no-audio-display" )) ;; please really never ever under any circumstance ever show yourself
  (setq emms-source-file-default-directory "~/Downloads/music"))

(use-package ytdl
  :config
  (setq ytdl-music-folder "~/music"))

(provide 'multimedia)
