;; -*- lexical-binding: t -*-

(add-to-list 'default-frame-alist '(font . "FiraCode Nerd Font 18"))
;;(set-face-attribute 'default nil :font "Terminus-18" )
;;(add-to-list 'default-frame-alist '(font . "Hack 12"))

(when window-system
  (let* ((home-monitor "C32HG7x")
	 (internal "0x08cf")
	 (office "HDMI-1")
	 (current (cdr (assoc 'name (car (display-monitor-attributes-list))))))
    (cond
     ((string= current home-monitor)
      (set-frame-position (selected-frame) 0 0)
      (set-frame-size (selected-frame) 200 80))
     ((string= current office)
      (set-frame-position (selected-frame) 0 0)
      (set-frame-size (selected-frame) 140 65))
     ((string= current internal)
      (set-frame-position (selected-frame) 0 0)
      (set-frame-size (selected-frame) 120 40)))))

(provide 'rez-linux)
