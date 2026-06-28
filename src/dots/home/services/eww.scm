;;; eww (widget system): package in the home profile, config under ~/.config/eww,
;;; launched from the compositor startups. The style is generated from the theme
;;; (palette + mono font); the .yuck layout and the babashka feeders are curated
;;; files. Returns home-xdg-configuration-files entries.

(define-module (dots home services eww)
  #:use-module (guix gexp)
  #:use-module (ice-9 format)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:use-module (gnu services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu services shepherd)
  #:use-module (dots theme base)
  #:use-module (dots config css)
  #:export (eww-style
            eww-capability
            home-eww-broker-service-type))

(define (eww-style-overrides theme)
  "Trailing rules appended after the main sheet so the cascade picks them: the
sidebar reads as frosted glass over the wallpaper instead of a solid slab, and
the echo strip becomes a designed status line with an accent prompt segment."
  (define (c role) (theme-color theme role))
  ;; echo: a powerline status line. The strip itself is transparent; only the
  ;; accent cap and the body carry colour, so it reads as a slanted pill that
  ;; ramps out from under the sidebar rather than a full-width box.
  (define body  (hex->rgba (c 'bg) 0.88))
  (define wedge "26px")                       ; glyph size ~ strip height
  `((".bar" (background-color . ,(hex->rgba (c 'bg) 0.72))
            (border . ,(string-append "1px solid " (c 'border)))
            ;; blur only, no spread, kept within the 6px margin so the halo's
            ;; corners stay rounded instead of being clipped square.
            (box-shadow . "0 0 5px 0 #0a0a10"))
    (".echo" (background-color . "transparent"))
    (".echo-lead" (min-width . "70px") (background-color . "transparent"))
    (".echo-tip" (color . ,(c 'accent)) (background-color . "transparent")
                 (font-size . ,wedge) (margin-right . "-1px"))
    (".echo-prompt" (background-color . ,(c 'accent)) (color . ,(c 'accent-fg)))
    (".echo-ico" (color . ,(c 'accent-fg)) (font-size . "13px") (padding . "0 6px"))
    (".echo-slant" (color . ,(c 'accent)) (background-color . ,body)
                   (font-size . ,wedge) (margin . "0 -1px"))
    (".echo-body" (background-color . ,body))
    (".echo-text" (color . ,(c 'fg)) (font-size . "13px") (padding . "0 12px"))
    (".echo-stat" (color . ,(c 'fg-dim)) (font-size . "12px") (padding . "0 16px 0 8px"))))

(define (eww-style theme)
  "Return the eww eww.scss themed from THEME, as CSS over a data description.
Read top-down: tunables, then bar, popups, control panel; the overrides are
appended last so the cascade picks them."
  (define (c role) (theme-color theme role))
  (define mono     (format #f "~s" (fonts-mono (theme-fonts theme))))
  (define cell     "40px")   ; bar icon cell: every clickable icon is this wide
  (define cell-pad "9px 0")  ; ... vertical only; width comes from `cell'
  (define cell-rad "12px")
  (define glyph    "16px")   ; uniform bar glyph size
  (define popup-rad "20px")  ; popup window corner
  (define card-rad  "15px")  ; inner card / list / config corner
  (define shadow      "0 2px 6px 2px #0a0a10")
  (define glass       (hex->rgba (c 'bg) 0.72))
  (define glass-card  (hex->rgba (c 'bg-dim) 0.5))
  (define glass-inset (hex->rgba (c 'bg) 0.4))
  (define glass-edge  (string-append "1px solid " (c 'border)))
  (define glass-sh    "0 0 5px 0 #0a0a10")
  (css
   (append
    `(;; reset + global font; transitions on the interactive bits
      ("*" (all . unset) (font-family . ,mono) (font-size . "13px"))
      ("button, eventbox" (transition . "background-color 0.25s, color 0.25s"))

      ;; ---- bar -------------------------------------------------------------
      (".bar" (background-color . ,(c 'bg)) (color . ,(c 'fg))
       (padding . "8px 0") (margin . "6px")
       (border-radius . "16px") (box-shadow . ,shadow))

      (".bgroup" (background-color . ,glass-card)
       (border-radius . "16px") (padding . "6px 4px"))

      (".viewer, .picker, .launch, .grp-apps .app, .icon, .net, .media, .ctl, .workspaces .ws"
       (background-color . ,(c 'bg-alt)) (color . ,(c 'fg-alt))
       (min-width . ,cell) (padding . ,cell-pad)
       (border-radius . ,cell-rad) (margin . "3px 0")
       (font-size . ,glyph))
      (".net" (color . ,(c 'cyan)))
      (".ctl" (color . ,(c 'accent)))
      (".viewer .bar-glyph" (margin-right . "2px"))
      (".picker .bar-glyph" (margin-right . "2px"))
      (".launch .bar-glyph" (margin-right . "0px"))
      (".term .bar-glyph" (margin-right . "0px"))
      (".web .bar-glyph" (margin-right . "0px"))
      (".files .bar-glyph" (margin-right . "0px"))
      (".edit .bar-glyph" (margin-right . "0px"))
      (".icon .bar-glyph" (margin-right . "3px"))
      (".media .bar-glyph" (margin-right . "5px"))
      (".net .bar-glyph" (margin-right . "6px"))
      (".ctl .bar-glyph" (margin-right . "4px"))
      (".workspaces .ws .bar-glyph" (margin-left . "2px"))
      (".workspaces .ws.current" (color . ,(c 'accent-fg)) (background-color . ,(c 'accent)))

      (".viewer:hover, .picker:hover, .launch:hover, .grp-apps .app:hover, .icon:hover, .net:hover, .media:hover, .ctl:hover, .clock:hover, .workspaces .ws:hover"
       (background-color . ,(c 'bg-active)) (color . ,(c 'accent-fg)))

      (".clock" (color . ,(c 'fg)) (margin-top . "6px"))
      (".clock .hour" (font-size . "15px") (font-weight . "bold"))
      (".clock .min" (color . ,(c 'fg-dim)) (font-size . "15px"))

      ;; ---- calendar --------------------------------------------------------
      (".cal-box" (background-color . ,glass-card) (border-radius . ,card-rad) (padding . "10px"))
      ("calendar" (color . ,(c 'fg)))
      ("calendar:selected" (background-color . ,(c 'accent)) (color . ,(c 'accent-fg)))

      ;; ---- popup chrome shared by every menu -------------------------------
      (".netmenu" (background-color . ,glass) (color . ,(c 'fg))
       (border . ,glass-edge)
       (border-radius . ,popup-rad) (padding . "8px") (margin . "8px")
       (box-shadow . ,glass-sh) (min-width . "360px"))

      ;; ---- network menu (card style) ---------------------------------------
      (".nm-card" (background-color . ,glass-card) (border-radius . ,card-rad)
       (padding . "12px") (margin . "6px"))
      (".nm-head" (padding . "12px 14px"))
      (".nm-head-ico" (font-size . "22px") (color . ,(c 'accent)) (margin-right . "14px"))
      (".nm-title" (font-size . "17px") (font-weight . "bold") (color . ,(c 'fg)))
      (".nm-sub" (font-size . "13px"))
      (".nm-sub.on" (color . ,(c 'green)))
      (".nm-sub.off" (color . ,(c 'fg-dim)))
      (".nm-list-card" (padding . "6px"))
      (".nm-scroll" (min-height . "14rem"))
      (".nm-row" (background-color . "transparent") (border . "none")
       (box-shadow . "none") (outline . "none")
       (border-radius . "12px") (padding . "10px 12px") (margin . "2px")
       (transition . "background-color 0.2s"))
      (".nm-row:hover" (background-color . ,(c 'bg-active)))
      (".nm-row.active" (background-color . ,(c 'bg-alt)))
      (".nm-row.sel" (background-color . ,(c 'bg-active))
       (box-shadow . ,(string-append "inset 3px 0 0 0 " (c 'accent))))
      (".nm-sig" (font-size . "14px") (color . ,(c 'fg-dim)))
      (".nm-sig.hi" (color . ,(c 'green)))
      (".nm-sig.mid" (color . ,(c 'yellow)))
      (".nm-sig.lo" (color . ,(c 'red)))
      (".nm-name" (font-size . "14px") (color . ,(c 'fg)))
      (".nm-name.active" (color . ,(c 'green)) (font-weight . "bold"))
      (".nm-lock" (font-size . "12px") (color . ,(c 'fg-dim)))
      (".nm-check" (font-size . "13px") (color . ,(c 'green)))
      (".nm-actions" (padding . "6px 4px 2px 4px"))
      (".nm-btn" (background-color . ,(c 'bg-active)) (color . ,(c 'fg))
       (border . "none") (box-shadow . "none") (outline . "none")
       (padding . "10px 20px") (border-radius . "12px")
       (transition . "background-color 0.2s, color 0.2s"))
      (".nm-btn:hover" (background-color . ,(c 'bg-alt)))
      (".nm-btn.go" (background-color . ,(c 'accent)) (color . ,(c 'accent-fg)))
      (".nm-btn.no" (color . ,(c 'red)))

      ;; ---- subheader (audio "Output" label) --------------------------------
      (".nm-subhead" (font-size . "13px") (color . ,(c 'fg-dim)) (margin . "2px 4px 8px 4px"))

      ;; ---- sliders shared by the audio + media menus -----------------------
      (".menu-slider trough" (background-color . ,(c 'bg-alt)) (min-height . "8px") (border-radius . "5px"))
      (".menu-slider trough highlight" (background-color . ,(c 'accent)) (border-radius . "5px"))

      ;; ---- audio menu ------------------------------------------------------
      (".audio-mute" (color . ,(c 'cyan)) (font-size . "20px") (padding . "0 4px"))
      (".audio-mute:hover" (color . ,(c 'accent)))
      (".audio-pct" (color . ,(c 'fg-dim)) (min-width . "38px"))

      ;; ---- media player (card vocabulary) ----------------------------------
      (".media-info" (padding . "2px 2px 12px 2px"))
      (".media-art" (min-width . "64px") (min-height . "64px")
       (border-radius . "12px") (background-size . "cover")
       (background-position . "center") (background-color . ,(c 'bg-active)))
      (".media-art-ico" (font-size . "26px") (color . ,(c 'fg-dim)))
      (".media-title" (font-size . "15px") (font-weight . "bold") (color . ,(c 'fg)))
      (".media-artist" (color . ,(c 'fg-dim)))
      (".media-times" (padding . "6px 2px 2px 2px"))
      (".media-time" (font-size . "11px") (color . ,(c 'fg-dim)))
      (".media-ctrl" (padding . "10px 0 2px 0"))
      (".media-btn" (color . ,(c 'fg)) (font-size . "20px") (padding . "6px"))
      (".media-btn:hover" (color . ,(c 'accent)))
      (".media-none-box" (padding . "8px"))
      (".media-none" (color . ,(c 'fg-dim)) (padding . "14px"))

      ;; ---- control panel: cards (profile / stats / sliders) ----------------
      (".ctlpanel-box" (padding . "4px"))
      (".ctl-card" (background-color . ,glass-card) (border-radius . ,card-rad)
       (padding . "14px") (margin . "6px"))
      (".ctl-profile" (padding . "2px"))
      (".ctl-pfp" (background-color . ,(c 'bg-active)) (border-radius . "100%")
       (min-width . "58px") (min-height . "58px") (margin-right . "16px"))
      (".ctl-pfp-ico" (font-size . "28px") (color . ,(c 'accent)))
      (".ctl-user" (font-size . "24px") (font-weight . "bold") (color . ,(c 'accent)))
      (".ctl-uptime" (color . ,(c 'fg-dim)))
      (".ctl-power" (background-color . ,glass-inset) (border-radius . "14px")
       (padding . "12px 8px") (margin-top . "14px"))
      (".ctl-power .pw-a" (font-size . "22px") (padding . "4px 12px") (transition . "color 0.25s"))
      (".ctl-power .lock" (color . ,(c 'blue)))
      (".ctl-power .logout" (color . ,(c 'yellow)))
      (".ctl-power .reboot" (color . ,(c 'magenta)))
      (".ctl-power .suspend" (color . ,(c 'cyan)))
      (".ctl-power .off" (color . ,(c 'red)))
      (".ctl-power .pw-a:hover" (color . ,(c 'fg)))

      ;; rings
      (".ctl-rings" (padding . "4px 0"))
      (".ctl-ring-box" (background-color . ,glass-inset) (border-radius . "14px")
       (padding . "10px 8px") (margin . "0 4px"))
      (".ctl-ring" (background-color . ,(c 'bg-active)) (border-radius . "100px") (margin-top . "4px"))
      (".ctl-ring.cpu" (color . ,(c 'red)))
      (".ctl-ring.ram" (color . ,(c 'blue)))
      (".ctl-ring.disk" (color . ,(c 'green)))
      (".ctl-ring.temp" (color . ,(c 'yellow)))
      (".ctl-ring-ico" (font-size . "18px") (margin . "14px"))
      (".ctl-ring-box.cpu .ctl-ring-ico"  (margin-left . "11px") (margin-right . "17px"))
      (".ctl-ring-box.ram .ctl-ring-ico"  (margin-left . "11px") (margin-right . "17px"))
      (".ctl-ring-box.disk .ctl-ring-ico" (margin-left . "11px") (margin-right . "17px"))
      (".ctl-ring-box.cpu .ctl-ring-ico, .ctl-ring-box.cpu .ctl-ring-lbl" (color . ,(c 'red)))
      (".ctl-ring-box.ram .ctl-ring-ico, .ctl-ring-box.ram .ctl-ring-lbl" (color . ,(c 'blue)))
      (".ctl-ring-box.disk .ctl-ring-ico, .ctl-ring-box.disk .ctl-ring-lbl" (color . ,(c 'green)))
      (".ctl-ring-box.temp .ctl-ring-ico, .ctl-ring-box.temp .ctl-ring-lbl" (color . ,(c 'yellow)))
      (".ctl-ring-lbl" (font-size . "11px") (margin-top . "6px"))
      (".ctl-srow" (padding . "4px 8px"))
      (".ctl-sico.vol" (color . ,(c 'accent)) (font-size . "17px"))
      (".ctl-sico.bri" (color . ,(c 'yellow)) (font-size . "17px"))
      (".ctl-scale trough" (background-color . ,(c 'bg))
       (min-height . "10px") (min-width . "180px") (border-radius . "50px"))
      (".ctl-scale.vol trough highlight" (background-color . ,(c 'accent)) (border-radius . "10px"))
      (".ctl-scale.bri trough highlight" (background-color . ,(c 'yellow)) (border-radius . "10px"))

      ;; ---- echo strip (base; eww-style-overrides restyles it) --------------
      (".echo" (background-color . ,(c 'bg)))
      (".echo-text" (color . ,(c 'fg)) (font-size . "13px") (padding . "0 12px 0 64px")))
    (eww-style-overrides theme))))

;;; The .yuck layout is authored as modules for editing, but `include' cannot
;;; work once deployed: home-xdg-configuration-files makes each file its own
;;; store object symlinked separately into ~/.config/eww, so eww canonicalises
;;; eww.yuck to its bare /gnu/store path and a sibling `./bar.yuck' is not there.
;;; So we concatenate the modules into ONE eww.yuck at build time. Edit the
;;; module files; the order below is the order they are stitched.
(define eww-yuck-modules
  '("eww.yuck" "bar.yuck" "network.yuck" "audio.yuck"
    "media.yuck" "control.yuck" "echo.yuck"))

(define (slurp path)
  (call-with-input-file path get-string-all))

(define (drop-includes text)
  "Remove `(include ...)' lines"
  (string-join
   (remove (lambda (line) (string-prefix? "(include" (string-trim line)))
           (string-split text #\newline))
   "\n"))

(define (combined-yuck config-dir)
  (string-join
   (map (lambda (name) (drop-includes (slurp (string-append config-dir "/eww/" name))))
        eww-yuck-modules)
   "\n"))

(define (eww-capability theme config-dir)
  "Return home-xdg-configuration-files entries for eww: the themed style, the
layout (modules concatenated into one eww.yuck), and the bb service. "
  (define (curated name)
    (list (string-append "eww/" name)
          (local-file (string-append config-dir "/eww/" name))))
  `(("eww/eww.scss"
     ,(plain-file "eww.scss" (eww-style theme)))
    ("eww/eww.yuck"
     ,(plain-file "eww.yuck" (combined-yuck config-dir)))
    ,(curated "broker.bb")
    ,(curated "eww-rpc")
    ,(curated "menu-toggle")
    ,(curated "niri-window-switch.bb")
    ,(curated "brightness")
    ,(curated "brightness-set")))

(define (home-eww-broker-shepherd-service config)
  (list
   (shepherd-service
    (provision '(eww-broker))
    (documentation "Live babashka broker feeding the eww bar (nREPL :1667).")
    (start #~(make-forkexec-constructor
              (list (string-append (getenv "HOME") "/.guix-home/profile/bin/bb")
                    (string-append (getenv "HOME") "/.config/eww/broker.bb"))
              #:log-file (string-append
                          (or (getenv "XDG_STATE_HOME")
                              (string-append (getenv "HOME") "/.local/state"))
                          "/eww-broker.log")))
    (stop #~(make-kill-destructor))
    (respawn? #t))))

(define home-eww-broker-service-type
  (service-type
   (name 'home-eww-broker)
   (extensions
    (list (service-extension home-shepherd-service-type
                             home-eww-broker-shepherd-service)))
   (default-value #f)
   (description "eww data broker shepherd service.")))
