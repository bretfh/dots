(in-package #:pine/user)

;;; What this machine runs. Nothing here is privileged: the systems are loaded the
;;; way any system is, the surfaces are declared the way pine's own are, and the
;;; classes below are the machine's classes.

;;; Where the windows go, where pine is the one saying it. Core has outputs,
;;; windows and what has the keyboard, and is told the name of the system that
;;; decides the rest. Written before the wm comes up, because that is when it
;;; is read -- and again when a compositor hands the windows over later.

(write /wm-places "tiles")

(use :host)
(use :text)
(use :edit)
(use :term)
(use :wm)
(use :desk)

(attend "audio")
(attend "screen")
(attend "power")
(attend "net")
(attend "media" :player "emms")
(attend "clip")

(write /theme/active :ef-dream)
(write /wm-terminal "alacritty")

(defmethod setting ((m text) key)
  (case key (:tab-width 2) (t (call-next-method))))

;;; A kind of surface: a strip along the bottom of the screen, always up. One
;;; ANCHOR method and one ASKS is the whole of adding one; the painter is told
;;; what this says and needs to know nothing else about it.

(defclass echo (overlay) ()
  (:documentation "A strip across the bottom of the screen."))

(defmethod asks ((r echo)) nil)

(defmethod anchor ((r echo) width height)
  (declare (ignore width))
  (map :edges '(:bottom :left :right) :wide 0 :tall height :keeps 0
       :margin '(0 0 0 0)))

;;; What the surfaces below are built out of.

(defun glyph (code) (string (code-char code)))

(defun run-line (line) (run "sh" (list line)))

(defun toggles (name) (lambda () (run "toggle-surface" (list name))))

(defun ib (code class &rest args)
  (apply #'icon code :class class :glyph-class "bar-glyph" :font 15 args))

(defun launcher (code class hint line)
  (ib code class :hint hint :click (lambda () (run-line line))))

(defun workspace-icons ()
  (mapcar (lambda (n)
            (let ((where (at nil "wm" "workspaces" n)))
              (icon n :font 15 :glyph-class "bar-glyph"
                      :class (if (getf (read where) :focused) "ws ws-current" "ws")
                      :click where)))
          (sort (copy-list (or (read /wm/workspaces) (list))) #'string<)))

(defsurface bar (:as 'bar)
  (centerbox :class "bar"
    :start
    (column :align :center :spacing 12
      (column :class "bgroup grp-overview" :align :center
        (ib #x0F02C1 "viewer" :hint "Overview" :click "wm-overview"))
      (apply #'column :class "bgroup grp-nav" :align :center :spacing 6
             (launcher #x0F002 "picker" "Search windows" "setsid -f fuzzel")
             (workspace-icons)))
    :center
    (column :class "bgroup grp-apps" :align :center :spacing 8
      (launcher #x0F003B "launch"    "Applications" "setsid -f fuzzel")
      (launcher #x0F120  "app term"  "Terminal"     "setsid -f alacritty")
      (launcher #x0F268  "app web"   "Browser"      "setsid -f google-chrome")
      (launcher #x0F07B  "app files" "Files"        "setsid -f nautilus")
      (launcher #x0F121  "app edit"  "Editor"       "emacsclient -c -n"))
    :end
    (column :align :center :spacing 12
      (column :class "bgroup grp-tray" :align :center :spacing 10
        (ib #x0F028 "icon"  :hint "Volume"  :click (map /surface/audio/shown (seq :toggle)))
        (ib #x0F001 "media" :hint "Media"   :click (map /surface/media/shown (seq :toggle)))
        (ib #x0F1EB "net"   :hint "Network" :click (map /surface/network/shown (seq :toggle))))
      (button :class "clock" :hint "Calendar"
              :click (map /surface/calendar/shown (seq :toggle))
        (column :align :center
          (label /dev/clock/hour   :class "hour")
          (label /dev/clock/minute :class "min")))
      (ib #x0F007 "corner-sq" :hint "System"
          :click (map /surface/ctl/shown (seq :toggle))))))

(defsurface echo (:as 'echo)
  (row :class "echo" :align :center
    (column :class "echo-lead")
    (row :class "echo-body" :align :center :expand 1
      (label (let ((title (run "wm-title")))
               (if (and title (plusp (length title)))
                   title
                   (format nil "~a@~a" (read /sys/user) (read /sys/host))))
             :class "echo-text" :expand 1)
      (label (format nil "~a   ~a ~d%"
                     (or (read /dev/net/connection) "offline")
                     (glyph (if (read /dev/audio/muted) #x0F075F #x0F057E))
                     (or (read /dev/audio/volume) 0))
             :class "echo-stat"))))

(defun nm-head (code title sub on)
  (row :class "nm-card nm-head" :align :center
    (icon code :class "nm-head-ico")
    (column :expand 1
      (label title :class "nm-title")
      (label sub :class (if on "nm-sub on" "nm-sub")))))

(defun mmss (seconds)
  (let ((s (or seconds 0)))
    (format nil "~d:~2,'0d" (floor s 60) (mod (floor s) 60))))

(defun signal-class (strength)
  (let ((s (or strength 0)))
    (cond ((>= s 66) "nm-sig hi")
          ((>= s 33) "nm-sig mid")
          (t "nm-sig lo"))))

(defun uptime-string (seconds)
  (let ((s (or seconds 0)))
    (format nil "up ~dh ~dm" (floor s 3600) (mod (floor s 60) 60))))

(defsurface calendar (:as 'panel)
  (column :class "netmenu cal-box" :align :stretch
    (calendar :year  (or (read /dev/clock/year) 2000)
              :month (or (read /dev/clock/month) 1)
              :day   (or (read /dev/clock/day) 1))))

(defun sink-row (sink)
  (let ((name (getf sink :name))
        (current (getf sink :default)))
    (choice :class (if current "nm-row active" "nm-row")
            :click (map /dev/audio/sink name)
      (row :align :center :spacing 10
        (icon #x0F028 :class "nm-sig")
        (label name :expand 1 :class (if current "nm-name active" "nm-name"))
        (label (if current (glyph #x0F012C) "") :class "nm-check")))))

(defsurface audio (:as 'panel)
  (column :class "netmenu" :align :stretch
    (nm-head #x0F028 "Audio"
             (format nil "~d%~a" (or (read /dev/audio/volume) 0)
                     (if (read /dev/audio/muted) "  muted" ""))
             (not (read /dev/audio/muted)))
    (column :class "nm-card" :align :stretch
      (row :align :center :spacing 12
        (icon (if (read /dev/audio/muted) #x0F026 #x0F028) :class "audio-mute"
              :click (map /dev/audio/muted (seq :toggle)))
        (slider /dev/audio/volume :class "menu-slider" :low 0 :high 100 :expand 1)
        (label (format nil "~d%" (or (read /dev/audio/volume) 0)) :class "audio-pct")))
    (column :class "nm-card nm-list-card" :align :stretch
      (label "Output" :class "nm-subhead")
      (scroll :tall 160 :class "nm-scroll"
        (apply #'column :align :stretch :spacing 2
               (mapcar #'sink-row (or (read /dev/audio/sinks) (list))))))))

(defun wifi-row (each)
  (let ((ssid (getf each :ssid))
        (up (getf each :in-use)))
    (choice :class (if up "nm-row active" "nm-row")
            :click (map /dev/net/wifi ssid)
      (row :align :center :spacing 10
        (icon #x0F1EB :class (signal-class (getf each :signal)))
        (label ssid :expand 1 :class (if up "nm-name active" "nm-name"))
        (label (if (getf each :secure) (glyph #x0F0341) "") :class "nm-lock")))))

(defsurface network (:as 'panel)
  (column :class "netmenu" :align :stretch
    (nm-head #x0F1EB "Network" (or (read /dev/net/connection) "Disconnected")
             (read /dev/net/online))
    (column :class "nm-card nm-list-card" :align :stretch
      (scroll :tall 260 :class "nm-scroll"
        (apply #'column :align :stretch :spacing 2
               (mapcar #'wifi-row (or (read /dev/net/wifi) (list)))))
      (row :class "nm-actions" :align :center :spacing 8
        (button :class "nm-btn" :click (map /dev/net/wifi :rescan)
          (label "Scan"))))))

(defsurface media (:as 'panel)
  (let ((status (read /dev/media/status)))
    (column :class "netmenu" :align :stretch
      (nm-head #x0F001 "Media" (if (eq status :playing) "Playing" "Idle")
               (eq status :playing))
      (if (null (read /dev/media/title))
          (column :class "nm-card media-none-box" :align :center
            (label "Nothing playing" :class "media-none"))
          (column :class "nm-card" :align :stretch
            (row :class "media-info" :align :center :spacing 14
              (center :class "media-art"
                (if (read /dev/media/art)
                    (image /dev/media/art)
                    (icon #x0F075A :class "media-art-ico")))
              (column :expand 1
                (label /dev/media/title  :class "media-title")
                (label (or (read /dev/media/artist) "") :class "media-artist")))
            (slider /dev/media/position :class "menu-slider"
                    :low 0 :high (or (read /dev/media/length) 1) :expand 1)
            (row :class "media-times" :align :center
              (label (mmss (read /dev/media/position)) :class "media-time" :expand 1)
              (label (mmss (read /dev/media/length))   :class "media-time"))
            (row :class "media-ctrl" :align :center :spacing 28
              (icon #x0F048 :class "media-btn" :click /dev/media/previous)
              (icon (if (eq status :playing) #x0F04C #x0F04B) :class "media-btn"
                    :click /dev/media/pause)
              (icon #x0F051 :class "media-btn" :click /dev/media/next)))))))

(defun ring-tile (code path cls name &optional (unit "%"))
  (column :class (format nil "ctl-ring-box ~a" cls) :align :center
    (ring path :class (format nil "ctl-ring ~a" cls)
          :low 0 :high 100 :thickness 5 :diameter 58
      (icon code :class "ctl-ring-ico"))
    (label (format nil "~a ~d~a" name (or (read path) 0) unit)
           :class "ctl-ring-lbl")))

(defun power-icon (code cls verb &optional confirm)
  (icon code :class (format nil "pw-a ~a" cls) :confirm confirm
             :click (at nil "dev" "power" verb)))

(defsurface ctl (:as 'panel)
  (column :class "netmenu ctlpanel-box" :align :stretch
    (column :class "ctl-card" :align :stretch :spacing 12
      (row :class "ctl-profile" :align :center
        (center :class "ctl-pfp" (icon #x0F007 :class "ctl-pfp-ico"))
        (column :expand 1
          (label /sys/user :class "ctl-user")
          (label (uptime-string (read /sys/uptime)) :class "ctl-uptime")))
      (row :class "ctl-power" :align :center :spacing 8
        (power-icon #x0F023 "lock"    "lock")
        (power-icon #x0F08B "logout"  "logout"   "Log out?")
        (power-icon #x0F021 "reboot"  "reboot"   "Reboot?")
        (power-icon #x0F186 "suspend" "suspend")
        (power-icon #x0F011 "off"     "poweroff" "Power off?")))
    (row :class "ctl-card ctl-rings" :align :center
      (ring-tile #x0F2DB  /sys/cpu  "cpu"  "CPU")
      (ring-tile #x0F1C0  /sys/ram  "ram"  "RAM")
      (ring-tile #x0F02CA /sys/disk "disk" "DSK")
      (ring-tile #x0F2C9  /sys/temp "temp" "TMP" "C"))
    (column :class "ctl-card" :align :stretch :spacing 16
      (row :class "ctl-srow" :align :center :spacing 14
        (icon #x0F028 :class "ctl-sico vol")
        (slider /dev/audio/volume :class "ctl-scale vol" :low 0 :high 100 :expand 1))
      (row :class "ctl-srow" :align :center :spacing 14
        (icon #x0F185 :class "ctl-sico bri")
        (slider /dev/screen/brightness :class "ctl-scale bri"
                :low 0 :high 100 :expand 1)))))

;;; The sheet. A selector is a class or classes: pine draws widgets, not elements,
;;; so what a rule can say is which widgets it means, not what a widget is made of.
;;; A slider's track is its :background-color and what it has filled is its :color.

(style ".editor-view" (list :opacity 0.9))

(style ".bar" (list :background-color (css-glass :bg) :color (color :fg)
                    :padding "8px 0 0 0"))
(style ".bgroup" (list :border-radius (css-rad) :padding "6px 4px"))
(style ".viewer, .picker, .launch, .app, .icon, .net, .media, .ctl, .ws"
       (list :color (color :fg-alt) :min-width "28px" :padding "8px 0"
             :border-radius (css-rad) :margin "3px 0" :font-size "15px"))
(style ".net" (list :color (color :cyan)))
(style ".ctl" (list :color (color :accent)))
(style ".ws-current" (list :color (color :accent-fg) :background-color (color :accent)
                           :min-width "28px" :padding "8px 0"
                           :border-radius (css-rad) :margin "3px 0"))
(style ".ws" (list :font-size "12px"))
(style ".viewer:hover, .picker:hover, .launch:hover, .app:hover, .icon:hover, .net:hover, .media:hover, .ctl:hover, .clock:hover, .ws:hover"
       (list :background-color (color :bg-active) :color (color :accent-fg)))
(style ".clock" (list :color (color :fg) :margin-top "6px"))
(style ".clock .hour" (list :font-size "15px" :font-weight "bold"))
(style ".clock .min" (list :color (color :fg-dim) :font-size "15px"))
(style ".corner-sq"
       (list :background-image (format nil "linear-gradient(135deg, ~a, ~a)"
                                       (color :accent) (color :magenta))
             :color (color :accent-fg) :min-width "28px" :min-height "28px"
             :border-radius "9px" :font-size "15px"))
(style ".icon .bar-glyph" (list :margin-right "3px"))
(style ".media .bar-glyph" (list :margin-right "5px"))
(style ".net .bar-glyph" (list :margin-right "6px"))
(style ".ctl .bar-glyph" (list :margin-right "4px"))
(style ".corner-sq .bar-glyph" (list :color (color :accent-fg) :font-size "15px"))

(style ".cal-box" (list :background-color (css-glass :bg-dim)
                        :border-radius (css-rad) :padding "10px"))

(style ".netmenu" (list :background-color (css-glass :bg) :color (color :fg)
                        :border-width "1px" :border-style "solid"
                        :border-color (color :border)
                        :border-radius (css-rad) :padding "8px" :margin "8px"
                        :box-shadow (format nil "0 0 5px 0 ~a" (color :shadow))
                        :min-width "360px"))
(style ".nm-card" (list :background-color (css-glass :bg-dim)
                        :border-radius (css-rad) :padding "12px" :margin "6px"))
(style ".nm-head" (list :padding "12px 14px"))
(style ".nm-head-ico" (list :font-size "22px" :color (color :accent)
                            :margin-right "14px"))
(style ".nm-title" (list :font-size "17px" :font-weight "bold" :color (color :fg)))
(style ".nm-sub" (list :font-size "13px"))
(style ".nm-sub.on" (list :color (color :green)))
(style ".nm-subhead" (list :font-size "13px" :color (color :fg-dim)
                           :margin "2px 4px 8px 4px"))
(style ".nm-list-card" (list :padding "6px"))
(style ".nm-scroll" (list :min-height "14rem"))
(style ".nm-row" (list :border-radius (css-rad) :padding "10px 12px" :margin "2px"))
(style ".nm-row:hover" (list :background-color (color :bg-active)))
(style ".nm-row.active" (list :background-color (color :bg-alt)))
(style ".nm-sig" (list :font-size "14px" :color (color :fg-dim)))
(style ".nm-sig.hi" (list :color (color :green)))
(style ".nm-sig.mid" (list :color (color :yellow)))
(style ".nm-sig.lo" (list :color (color :red)))
(style ".nm-name" (list :font-size "14px" :color (color :fg)))
(style ".nm-name.active" (list :color (color :green) :font-weight "bold"))
(style ".nm-lock" (list :font-size "12px" :color (color :fg-dim)))
(style ".nm-check" (list :font-size "13px" :color (color :green)))
(style ".nm-actions" (list :padding "6px 4px 2px 4px"))
(style ".nm-btn" (list :background-color (color :bg-active) :color (color :fg)
                       :padding "10px 20px" :border-radius (css-rad)))
(style ".nm-btn:hover" (list :background-color (color :bg-alt)))

(style ".menu-slider" (list :background-color (color :bg-alt) :color (color :accent)
                            :min-height "8px" :border-radius "5px"))

(style ".audio-mute" (list :color (color :cyan) :font-size "20px" :padding "0 4px"))
(style ".audio-mute:hover" (list :color (color :accent)))
(style ".audio-pct" (list :color (color :fg-dim) :min-width "38px"))

(style ".media-info" (list :padding "2px 2px 12px 2px"))
(style ".media-art" (list :min-width "64px" :min-height "64px"
                          :border-radius (css-rad)
                          :background-color (color :bg-active)))
(style ".media-art-ico" (list :font-size "26px" :color (color :fg-dim)))
(style ".media-title" (list :font-size "15px" :font-weight "bold" :color (color :fg)))
(style ".media-artist" (list :color (color :fg-dim)))
(style ".media-times" (list :padding "6px 2px 2px 2px"))
(style ".media-time" (list :font-size "11px" :color (color :fg-dim)))
(style ".media-ctrl" (list :padding "10px 0 2px 0"))
(style ".media-btn" (list :color (color :fg) :font-size "20px" :padding "6px"))
(style ".media-btn:hover" (list :color (color :accent)))
(style ".media-none-box" (list :padding "8px"))
(style ".media-none" (list :color (color :fg-dim) :padding "14px"))

(style ".ctlpanel-box" (list :padding "4px"))
(style ".ctl-card" (list :background-color (css-glass :bg-dim)
                         :border-radius (css-rad) :padding "14px" :margin "6px"))
(style ".ctl-profile" (list :padding "2px"))
(style ".ctl-pfp" (list :background-color (color :accent) :border-radius "100%"
                        :min-width "58px" :min-height "58px" :margin-right "16px"))
(style ".ctl-pfp-ico" (list :font-size "28px" :color (color :accent-fg)))
(style ".ctl-user" (list :font-size "24px" :font-weight "bold" :color (color :accent)))
(style ".ctl-uptime" (list :color (color :fg-dim)))
(style ".ctl-power" (list :background-color (css-glass :bg) :border-radius (css-rad)
                          :padding "12px 8px" :margin-top "14px"))
(style ".pw-a" (list :font-size "22px" :padding "4px 12px"))
(style ".pw-a.lock" (list :color (color :blue)))
(style ".pw-a.logout" (list :color (color :yellow)))
(style ".pw-a.reboot" (list :color (color :magenta)))
(style ".pw-a.suspend" (list :color (color :cyan)))
(style ".pw-a.off" (list :color (color :red)))
(style ".pw-a:hover" (list :color (color :fg)))
(style ".ctl-rings" (list :padding "4px 0"))
(style ".ctl-ring" (list :background-color (color :bg)))
(style ".ctl-ring-box" (list :background-color (css-glass :bg)
                             :border-radius (css-rad) :padding "10px 8px"
                             :margin "0 4px"))
(style ".ctl-ring-ico" (list :font-size "18px" :margin "14px"))
(style ".ctl-ring-lbl" (list :font-size "11px" :margin-top "6px"
                             :color (color :fg-dim)))
(style ".ctl-ring.cpu"  (list :color (color :red)))
(style ".ctl-ring.ram"  (list :color (color :blue)))
(style ".ctl-ring.disk" (list :color (color :green)))
(style ".ctl-ring.temp" (list :color (color :yellow)))
(style ".ctl-ring-box.cpu .ctl-ring-ico, .ctl-ring-box.cpu .ctl-ring-lbl"
       (list :color (color :red)))
(style ".ctl-ring-box.ram .ctl-ring-ico, .ctl-ring-box.ram .ctl-ring-lbl"
       (list :color (color :blue)))
(style ".ctl-ring-box.disk .ctl-ring-ico, .ctl-ring-box.disk .ctl-ring-lbl"
       (list :color (color :green)))
(style ".ctl-ring-box.temp .ctl-ring-ico, .ctl-ring-box.temp .ctl-ring-lbl"
       (list :color (color :yellow)))
(style ".ctl-srow" (list :padding "4px 8px"))
(style ".ctl-sico.vol" (list :color (color :accent) :font-size "17px"))
(style ".ctl-sico.bri" (list :color (color :yellow) :font-size "17px"))
(style ".ctl-scale" (list :background-color (color :bg) :min-height "10px"
                          :min-width "180px" :border-radius "50px"))
(style ".ctl-scale.vol" (list :color (color :accent)))
(style ".ctl-scale.bri" (list :color (color :yellow)))

(style ".echo" (list :background-color "transparent"))
(style ".echo-lead" (list :min-width "44px" :background-color "transparent"))
(style ".echo-body" (list :background-color (css-glass :bg)))
(style ".echo-text" (list :color (color :fg) :font-size "13px" :padding "0 12px"))
(style ".echo-stat" (list :color (color :fg-dim) :font-size "12px"
                          :padding "0 16px 0 8px"))

;;; Commands, and the chords that run them.

(defcommand "volume-up" () (:describes "the sink a little louder")
  (write /dev/audio/volume (min 100 (+ 5 (or (read /dev/audio/volume) 0)))))

(defcommand "volume-down" () (:describes "the sink a little quieter")
  (write /dev/audio/volume (max 0 (- (or (read /dev/audio/volume) 0) 5))))

(defcommand "mute" () (:describes "toggle the sink")
  (write /dev/audio/muted t))

(defcommand "brighter" () (:describes "the backlight up")
  (write /dev/screen/brightness (min 100 (+ 10 (or (read /dev/screen/brightness) 0)))))

(defcommand "dimmer" () (:describes "the backlight down")
  (write /dev/screen/brightness (max 1 (- (or (read /dev/screen/brightness) 0) 10))))

(defcommand "play-pause" () (:describes "the player, either way")
  (write /dev/media/pause t))

(defcommand "next-track" () (:describes "the track after this one")
  (write /dev/media/next t))

(defcommand "previous-track" () (:describes "the track before this one")
  (write /dev/media/previous t))

(defcommand "split-below" () (:describes "the window, one above the other")
  (run "wm-split" (list :below)))

(defcommand "split-beside" () (:describes "the window, side by side")
  (run "wm-split" (list :beside)))

(defcommand "status" () (:describes "what this machine is doing")
  (list :user (read /sys/user)
        :host (read /sys/host)
        :cpu (read /sys/cpu)
        :ram (read /sys/ram)
        :disk (read /sys/disk)
        :battery (read /dev/power/battery)
        :network (read /dev/net/connection)
        :volume (read /dev/audio/volume)
        :playing (read /dev/media/title)
        :window (run "wm-title")))

(bind 'text "C-c v" "volume-up")
(bind 'text "C-c V" "volume-down")
(bind 'text "C-c m" "mute")
(bind 'text "C-c b" "brighter")
(bind 'text "C-c B" "dimmer")
(bind 'text "C-c SPC" "play-pause")
(bind 'text "C-c n" "next-track")
(bind 'text "C-c p" "previous-track")
(bind 'text "C-c s" "status")

;;; The window manager's own. A chord in TEXT is heard while a document has the
;;; keyboard; one in WM the compositor takes and hands over whatever is focused,
;;; which is what these have to be. Under niri they say nothing: niri keeps its
;;; own.

(bind 'wm "s-Return" "wm-terminal")
(bind 'wm "s-q" "wm-close-window")
(bind 'wm "s-j" "wm-focus-next")
(bind 'wm "s-k" "wm-focus-previous")
(bind 'wm "s-w" "switch-to-window")
(bind 'wm "s-2" "split-below")
(bind 'wm "s-3" "split-beside")
(bind 'wm "s-S-e" "wm-exit")
