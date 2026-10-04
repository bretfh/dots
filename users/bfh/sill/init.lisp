(in-package #:sill/user)

;;; What this machine draws. Nothing here is privileged: the surfaces are
;;; declared the way sill's own are, and what is below is this machine's.

;; The running window manager, open to an editor: sly-connect to 4005 and it
;; is this image. (refresh) after redefining anything a surface is built out
;; of -- nothing it read moved, so nothing else would say the code did.
(start-slynk)

(setf (active) :ef-dream)

(device "audio")
(device "screen")
(device "power")
(device "net")
(device "media" :player "emms")
(device "clip")

(defvar *terminal* "alacritty")

;;; What the surfaces below are built out of.

(defun launch-line (line) (lambda () (run line)))

(defun ib (code class &rest args)
  (apply #'icon code :class class :glyph-class "bar-glyph" :font-size 15 args))

(defun launcher (code class said line)
  (ib code class :hint said :on-click (launch-line line)))

(defun a-window (each i)
  (declare (ignore i))
  (let ((id (getf each :id)))
    (ib 983745 (list "ws" (when (eql id (current-window)) "ws-current"))
        :hint (getf each :title)
        :on-click (lambda () (window-focus id)))))

(defsurface bar (:left 0 :top 0 :bottom 0 :reserve t :visible t)
            (centerbox :class "bar"
                       :start
                       (column :align :center :spacing 12
                               (column :class "bgroup grp-nav" :align :center :spacing 6
                                       (launcher 61442 "picker" "Search windows" "setsid -f fuzzel")
                                       (rows (windows) #'a-window)))
                       :center
                       (column :class "bgroup grp-apps" :align :center :spacing 8
                               (launcher 983099 "launch" "Applications" "setsid -f fuzzel")
                               (launcher 61728 "app term" "Terminal" (format nil "setsid -f ~a" *terminal*))
                               (launcher 62056 "app web" "Browser" "setsid -f google-chrome")
                               (launcher 61563 "app files" "Files" "setsid -f nautilus")
                               (launcher 61729 "app edit" "Editor" "emacsclient -c -n"))
                       :end
                       (column :align :center :spacing 12
                               (column :class "bgroup grp-tray" :align :center :spacing 10
                                       (ib 61480 "icon" :hint "Volume" :on-click '(toggle "audio"))
                                       (ib 61441 "media" :hint "Media" :on-click '(toggle "media"))
                                       (ib 61931 "net" :hint "Network" :on-click '(toggle "network")))
                               (button :class "clock" :hint "Calendar" :on-click '(toggle "calendar")
                                       (column :align :center
                                               (label (clock-hour) :class "hour")
                                               (label (clock-minute) :class "min")))
                               (ib 61447 "corner-sq" :hint "System" :on-click '(toggle "ctl")))))

(defun focused-title ()
  (let ((id (current-window)))
    (or (getf (find id (windows) :key (lambda (w) (getf w :id))) :title)
        (format nil "~a@~a" (sys-user) (sys-host)))))

(defsurface echo (:left 0 :right 0 :bottom 0 :visible t)
            (row :class "echo" :align :center
                 (column :class "echo-lead")
                 (row :class "echo-body" :align :center :expand 1
                      (label (focused-title) :class "echo-text" :expand 1)
                      (label (format nil "~a   ~a ~d%"
                                     (net-connection)
                                     (glyph (if (audio-muted) 984927 984446))
                                     (audio-volume))
                             :class "echo-stat"))))

(defun nm-head (code said sub on)
  (row :class "nm-card nm-head" :align :center
       (icon code :class "nm-head-ico")
       (column :expand 1
               (label said :class "nm-title")
               (label sub :class (list "nm-sub" (when on "on"))))))

(defun mmss (seconds)
  (let ((s (or seconds 0)))
    (format nil "~d:~2,'0d" (floor s 60) (mod (floor s) 60))))

(defun signal-class (strength)
  (let ((s (or strength 0)))
    (cond ((>= s 66) "hi") ((>= s 33) "mid") (t "lo"))))

(defun uptime-string (seconds)
  (format nil "up ~dh ~dm" (floor seconds 3600) (mod (floor seconds 60) 60)))

(defsurface calendar (:top 8 :left 8)
            (column :class "netmenu cal-box" :align :stretch
                    (calendar :year (clock-year) :month (clock-month) :day (clock-day))))

(defun sink-row (sink i)
  (declare (ignore i))
  (let ((said (getf sink :name))
        (current (getf sink :default)))
    (choice :class (list "nm-row" (when current "active"))
            :on-click (lambda () (setf (audio-sink) said))
            (row :align :center :spacing 10
                 (icon 61480 :class "nm-sig")
                 (label said :expand 1 :class (list "nm-name" (when current "active")))
                 (label (if current (glyph 983340) "") :class "nm-check")))))

(defsurface audio (:top 8 :left 8)
            (column :class "netmenu" :align :stretch
                    (nm-head 61480 "Audio"
                             (format nil "~d%~a" (audio-volume) (if (audio-muted) "  muted" ""))
                             (not (audio-muted)))
                    (column :class "nm-card" :align :stretch
                            (row :align :center :spacing 12
                                 (icon (if (audio-muted) 61478 61480) :class "audio-mute"
                                       :on-click '(toggle 'audio-muted))
                                 (slider 'audio-volume :class "menu-slider" :low 0 :high 100 :expand 1)
                                 (label (format nil "~d%" (audio-volume)) :class "audio-pct")))
                    (column :class "nm-card nm-list-card" :align :stretch
                            (label "Output" :class "nm-subhead")
                            (scroll :fixed-height 160 :class "nm-scroll"
                                    (rows (audio-sinks) #'sink-row)))))

(defun wifi-row (each i)
  (declare (ignore i))
  (let ((ssid (getf each :ssid))
        (up (getf each :in-use)))
    (choice :class (list "nm-row" (when up "active"))
            :on-click (lambda () (setf (net-wifi) ssid))
            (row :align :center :spacing 10
                 (icon 61931 :class (list "nm-sig" (signal-class (getf each :signal))))
                 (label ssid :expand 1 :class (list "nm-name" (when up "active")))
                 (label (if (getf each :secure) (glyph 983873) "") :class "nm-lock")))))

(defsurface network (:top 8 :left 8)
            (column :class "netmenu" :align :stretch
                    (nm-head 61931 "Network" (net-connection) (net-online))
                    (column :class "nm-card nm-list-card" :align :stretch
                            (scroll :fixed-height 260 :class "nm-scroll"
                                    (rows (net-wifi) #'wifi-row))
                            (row :class "nm-actions" :align :center :spacing 8
                                 (button :class "nm-btn" :on-click '(setf (net-wifi) :rescan)
                                         (label "Scan"))))))

(defsurface media (:top 8 :left 8)
            (let ((status (media-status)))
              (column :class "netmenu" :align :stretch
                      (nm-head 61441 "Media" (if (eq status :playing) "Playing" "Idle")
                               (eq status :playing))
                      (if (null (media-title))
                          (column :class "nm-card media-none-box" :align :center
                                  (label "Nothing playing" :class "media-none"))
                        (column :class "nm-card" :align :stretch
                                (row :class "media-info" :align :center :spacing 14
                                     (center :class "media-art"
                                             (let ((art (media-art)))
                                               (if art
                                                   (image (if (eql 0 (search "file://" art)) (subseq art 7) art))
                                                 (icon 984922 :class "media-art-ico"))))
                                     (column :expand 1
                                             (label (media-title) :class "media-title")
                                             (label (media-artist) :class "media-artist")))
                                (slider 'media-position :class "menu-slider"
                                        :low 0 :high (max 1 (media-length)) :expand 1)
                                (row :class "media-times" :align :center
                                     (label (mmss (media-position)) :class "media-time" :expand 1)
                                     (label (mmss (media-length)) :class "media-time"))
                                (row :class "media-ctrl" :align :center :spacing 28
                                     (icon 61512 :class "media-btn" :on-click 'media-previous)
                                     (icon (if (eq status :playing) 61516 61515) :class "media-btn"
                                           :on-click 'media-pause)
                                     (icon 61521 :class "media-btn" :on-click 'media-next)))))))

(defun ring-tile (code reading cls said &optional (unit "%"))
  (column :class (list "ctl-ring-box" cls) :align :center
          (ring reading :class (list "ctl-ring" cls)
                :low 0 :high 100 :thickness 5 :diameter 58
                (icon code :class "ctl-ring-ico"))
          (label (format nil "~a ~d~a" said (value reading) unit)
                 :class "ctl-ring-lbl")))

(defun power-icon (code cls does &optional confirm)
  (icon code :class (list "pw-a" cls) :confirm confirm :on-click does))

(defsurface ctl (:top 8 :left 8)
            (column :class "netmenu ctlpanel-box" :align :stretch
                    (column :class "ctl-card" :align :stretch :spacing 12
                            (row :class "ctl-profile" :align :center
                                 (center :class "ctl-pfp" (icon 61447 :class "ctl-pfp-ico"))
                                 (column :expand 1
                                         (label (sys-user) :class "ctl-user")
                                         (label (uptime-string (sys-uptime)) :class "ctl-uptime")))
                            (row :class "ctl-power" :align :center :spacing 8
                                 (power-icon 61475 "lock" 'power-lock)
                                 (power-icon 61579 "logout" 'power-logout "Log out?")
                                 (power-icon 61473 "reboot" 'power-reboot "Reboot?")
                                 (power-icon 61830 "suspend" 'power-suspend)
                                 (power-icon 61457 "off" 'power-poweroff "Power off?")))
                    (row :class "ctl-card ctl-rings" :align :center
                         (ring-tile 62171 'sys-cpu "cpu" "CPU")
                         (ring-tile 61888 'sys-ram "ram" "RAM")
                         (ring-tile 983754 'sys-disk "disk" "DSK")
                         (ring-tile 62153 'sys-temp "temp" "TMP" "C"))
                    (column :class "ctl-card" :align :stretch :spacing 16
                            (row :class "ctl-srow" :align :center :spacing 14
                                 (icon 61480 :class "ctl-sico vol")
                                 (slider 'audio-volume :class "ctl-scale vol" :low 0 :high 100 :expand 1))
                            (row :class "ctl-srow" :align :center :spacing 14
                                 (icon 61829 :class "ctl-sico bri")
                                 (slider 'screen-brightness :class "ctl-scale bri"
                                         :low 0 :high 100 :expand 1)))))

;;; The sheet. A selector is a class or classes: sill draws widgets, not
;;; elements, so what a rule can say is which widgets it means, not what a
;;; widget is made of. A slider's track is its :background-color and what it
;;; has filled is its :color.

(defparameter +bar-icons+
              '(".viewer" ".picker" ".launch" ".app" ".icon" ".net" ".media" ".ctl" ".ws"))

(style ".bar" :background-color (glass :bg) :color (color :fg)
       :padding "8px 0 0 0")
(style ".bgroup" :border-radius (radius) :padding "6px 4px")
(style (format nil "~{~a~^, ~}" +bar-icons+)
       :color (color :fg-alt) :min-width "28px" :padding "8px 0"
       :border-radius (radius) :margin "3px 0" :font-size "15px")
(style ".net" :color (color :cyan))
(style ".ctl" :color (color :accent))
(style ".ws-current" :color (color :accent-fg) :background-color (color :accent)
       :min-width "28px" :padding "8px 0"
       :border-radius (radius) :margin "3px 0")
(style ".ws" :font-size "12px")
(style (apply #'hovered ".clock" +bar-icons+)
       :background-color (color :bg-active) :color (color :accent-fg))
(style ".clock" :color (color :fg) :margin-top "6px")
(style ".clock .hour" :font-size "15px" :font-weight "bold")
(style ".clock .min" :color (color :fg-dim) :font-size "15px")
(style ".corner-sq"
       :background-image (format nil "linear-gradient(135deg, ~a, ~a)"
                                 (color :accent) (color :magenta))
       :color (color :accent-fg) :min-width "28px" :min-height "28px"
       :border-radius "9px" :font-size "15px")
(style ".icon .bar-glyph" :margin-right "3px")
(style ".media .bar-glyph" :margin-right "5px")
(style ".net .bar-glyph" :margin-right "6px")
(style ".ctl .bar-glyph" :margin-right "4px")
(style ".corner-sq .bar-glyph" :color (color :accent-fg) :font-size "15px")

(style ".cal-box" :background-color (glass :bg-dim)
       :border-radius (radius) :padding "10px")

(style ".netmenu" :background-color (glass :bg) :color (color :fg)
       :border-width "1px" :border-style "solid"
       :border-color (color :border)
       :border-radius (radius) :padding "8px" :margin "8px"
       :box-shadow (format nil "0 0 5px 0 ~a" (color :shadow))
       :min-width "360px")
(style ".nm-card" :background-color (glass :bg-dim)
       :border-radius (radius) :padding "12px" :margin "6px")
(style ".nm-head" :padding "12px 14px")
(style ".nm-head-ico" :font-size "22px" :color (color :accent)
       :margin-right "14px")
(style ".nm-title" :font-size "17px" :font-weight "bold" :color (color :fg))
(style ".nm-sub" :font-size "13px")
(style ".nm-sub.on" :color (color :green))
(style ".nm-subhead" :font-size "13px" :color (color :fg-dim)
       :margin "2px 4px 8px 4px")
(style ".nm-list-card" :padding "6px")
(style ".nm-scroll" :min-height "14rem")
(style ".nm-row" :border-radius (radius) :padding "10px 12px" :margin "2px")
(style (hovered ".nm-row") :background-color (color :bg-active))
(style ".nm-row.active" :background-color (color :bg-alt))
(style ".nm-sig" :font-size "14px" :color (color :fg-dim))
(style ".nm-sig.hi" :color (color :green))
(style ".nm-sig.mid" :color (color :yellow))
(style ".nm-sig.lo" :color (color :red))
(style ".nm-name" :font-size "14px" :color (color :fg))
(style ".nm-name.active" :color (color :green) :font-weight "bold")
(style ".nm-lock" :font-size "12px" :color (color :fg-dim))
(style ".nm-check" :font-size "13px" :color (color :green))
(style ".nm-actions" :padding "6px 4px 2px 4px")
(style ".nm-btn" :background-color (color :bg-active) :color (color :fg)
       :padding "10px 20px" :border-radius (radius))
(style (hovered ".nm-btn") :background-color (color :bg-alt))

(style ".menu-slider" :background-color (color :bg-alt) :color (color :accent)
       :min-height "8px" :border-radius "5px")

(style ".audio-mute" :color (color :cyan) :font-size "20px" :padding "0 4px")
(style (hovered ".audio-mute") :color (color :accent))
(style ".audio-pct" :color (color :fg-dim) :min-width "38px")

(style ".media-info" :padding "2px 2px 12px 2px")
(style ".media-art" :min-width "64px" :min-height "64px"
       :border-radius (radius)
       :background-color (color :bg-active))
(style ".media-art-ico" :font-size "26px" :color (color :fg-dim))
(style ".media-title" :font-size "15px" :font-weight "bold" :color (color :fg))
(style ".media-artist" :color (color :fg-dim))
(style ".media-times" :padding "6px 2px 2px 2px")
(style ".media-time" :font-size "11px" :color (color :fg-dim))
(style ".media-ctrl" :padding "10px 0 2px 0")
(style ".media-btn" :color (color :fg) :font-size "20px" :padding "6px")
(style (hovered ".media-btn") :color (color :accent))
(style ".media-none-box" :padding "8px")
(style ".media-none" :color (color :fg-dim) :padding "14px")

(style ".ctlpanel-box" :padding "4px")
(style ".ctl-card" :background-color (glass :bg-dim)
       :border-radius (radius) :padding "14px" :margin "6px")
(style ".ctl-profile" :padding "2px")
(style ".ctl-pfp" :background-color (color :accent) :border-radius "100%"
       :min-width "58px" :min-height "58px" :margin-right "16px")
(style ".ctl-pfp-ico" :font-size "28px" :color (color :accent-fg))
(style ".ctl-user" :font-size "24px" :font-weight "bold" :color (color :accent))
(style ".ctl-uptime" :color (color :fg-dim))
(style ".ctl-power" :background-color (glass :bg) :border-radius (radius)
       :padding "12px 8px" :margin-top "14px")
(style ".pw-a" :font-size "22px" :padding "4px 12px")
(style ".pw-a.lock" :color (color :blue))
(style ".pw-a.logout" :color (color :yellow))
(style ".pw-a.reboot" :color (color :magenta))
(style ".pw-a.suspend" :color (color :cyan))
(style ".pw-a.off" :color (color :red))
(style (hovered ".pw-a") :color (color :fg))
(style ".ctl-rings" :padding "4px 0")
(style ".ctl-ring" :background-color (color :bg))
(style ".ctl-ring-box" :background-color (glass :bg)
       :border-radius (radius) :padding "10px 8px"
       :margin "0 4px")
(style ".ctl-ring-ico" :font-size "18px" :margin "14px")
(style ".ctl-ring-lbl" :font-size "11px" :margin-top "6px"
       :color (color :fg-dim))
(style ".ctl-ring.cpu" :color (color :red))
(style ".ctl-ring.ram" :color (color :blue))
(style ".ctl-ring.disk" :color (color :green))
(style ".ctl-ring.temp" :color (color :yellow))
(style ".ctl-ring-box.cpu .ctl-ring-ico, .ctl-ring-box.cpu .ctl-ring-lbl"
       :color (color :red))
(style ".ctl-ring-box.ram .ctl-ring-ico, .ctl-ring-box.ram .ctl-ring-lbl"
       :color (color :blue))
(style ".ctl-ring-box.disk .ctl-ring-ico, .ctl-ring-box.disk .ctl-ring-lbl"
       :color (color :green))
(style ".ctl-ring-box.temp .ctl-ring-ico, .ctl-ring-box.temp .ctl-ring-lbl"
       :color (color :yellow))
(style ".ctl-srow" :padding "4px 8px")
(style ".ctl-sico.vol" :color (color :accent) :font-size "17px")
(style ".ctl-sico.bri" :color (color :yellow) :font-size "17px")
(style ".ctl-scale" :background-color (color :bg) :min-height "10px"
       :min-width "180px" :border-radius "50px")
(style ".ctl-scale.vol" :color (color :accent))
(style ".ctl-scale.bri" :color (color :yellow))

(style ".echo" :background-color "transparent")
(style ".echo-lead" :min-width "44px" :background-color "transparent")
(style ".echo-body" :background-color (glass :bg))
(style ".echo-text" :color (color :fg) :font-size "13px" :padding "0 12px")
(style ".echo-stat" :color (color :fg-dim) :font-size "12px"
       :padding "0 16px 0 8px")

;;; The chords. The compositor takes these and hands over whatever is focused,
;;; so they are the ones that have to work with a window in front of them.

(setq-default 'terminal *terminal*)

(global-set-key "s-RET" '(run (mode-value 'terminal)))
(global-set-key "s-p"   '(run "setsid -f fuzzel"))
(global-set-key "s-q"   '(window-close))
(global-set-key "s-j"   '(window-next))
(global-set-key "s-k"   '(window-previous))
(global-set-key "s-w"   '(toggle "ctl"))
(global-set-key "s-2"   '(setf (layout) (wide :gaps 6)))
(global-set-key "s-3"   '(setf (layout) (tall :gaps 6)))
(global-set-key "s-f"   '(setf (layout) (full)))
(global-set-key "s-S-e" '(end-session))

(global-set-key "XF86AudioRaiseVolume"  '(step-value 'audio-volume 5))
(global-set-key "XF86AudioLowerVolume"  '(step-value 'audio-volume -5))
(global-set-key "XF86AudioMute"         '(toggle 'audio-muted))
(global-set-key "XF86MonBrightnessUp"   '(step-value 'screen-brightness 10 :low 1))
(global-set-key "XF86MonBrightnessDown" '(step-value 'screen-brightness -10 :low 1))
(global-set-key "XF86AudioPlay" 'media-pause)
(global-set-key "XF86AudioNext" 'media-next)
(global-set-key "XF86AudioPrev" 'media-previous)

;;; A mode of my own: while a video is up the windows sit full with a wide
;;; margin and the terminal it opens is bigger. A mode is a class, so this one
;;; keeps every chord above and says more.

(define-mode watching (mode))

(setq-mode 'watching 'terminal (format nil "~a --option font.size=16" *terminal*))

(define-key 'watching "s-f" '(setf (layout) (full :gaps 48)))

(global-set-key "s-v"
                '(progn (setf (current-mode)
                              (if (typep (current-mode) 'watching) 'mode 'watching))
                        (setf (layout)
                              (if (typep (current-mode) 'watching)
                                  (full :gaps 48)
                                (tall :gaps 6)))))

(setf (layout) (tall :gaps 6))
