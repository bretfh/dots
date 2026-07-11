(defpackage #:pine.source
  (:use #:cl)
  (:export #:start-sources #:stop-sources #:workspaces
           #:defsource #:defpoll #:set! #:cell-of
           #:select! #:act!))

(in-package #:pine.source)

;;;; Data sources feed reactive cells; widgets read those cells and re-render on
;;;; change. A source is either a STREAM (a subprocess line stream that triggers
;;;; a refresh, event-driven) or a POLL (a refresh on an interval). Either way
;;;; the actual work (shell reads + set-cell) runs on a source actor owned by
;;;; the actor system, off both the reader thread and the timer thread. Sources
;;;; are declared with defsource / defpoll and started together by start-sources.
;;;; This is the runtime behind the widgets' cell reads -- pine's eww broker.

(defun cell-of (name)
  (or (pine.cell:find-cell name) (pine.cell:make-cell :name name)))

(defun set! (name value)
  "Set reactive cell NAME to VALUE (deduped by the cell)."
  (pine.cell:set-cell (cell-of name) value))

;;; shell helpers

(defun sh (&rest args)
  (or (ignore-errors
        (string-trim '(#\newline #\space)
                     (uiop:run-program args :output :string :ignore-error-status t)))
      ""))

(defun %first-number (s)
  (let ((start (position-if (lambda (c) (or (digit-char-p c) (char= c #\.))) s)))
    (when start
      (let ((end (or (position-if-not (lambda (c) (or (digit-char-p c) (char= c #\.)))
                                       s :start start)
                     (length s))))
        (ignore-errors (read-from-string (subseq s start end)))))))

(defun read-int-file (path)
  (ignore-errors (parse-integer (sh "cat" (namestring path)))))

;;; source primitives

(defstruct source actor process)

(defun %actor (system refresh-fn)
  (sento.actor-context:actor-of system
    :name "pine-source"
    :receive (lambda (msg)
               (case (first msg)
                 ((:refresh :poll) (ignore-errors (funcall refresh-fn)))
                 (t nil)))))

(defun start-stream (system command refresh-fn &optional (trigger (constantly t)))
  "Spawn COMMAND; when a stdout line satisfies TRIGGER, run REFRESH-FN on the
source actor (REFRESH-FN sets cells). The reader thread only forwards events;
stopping terminates the process so it hits EOF and exits. No thread is killed."
  (let* ((actor (%actor system refresh-fn))
         (proc (uiop:launch-program (list "sh" "-c" command) :output :stream)))
    (sento.actor:tell actor '(:refresh))
    (bordeaux-threads:make-thread
     (lambda ()
       (handler-case
           (loop with out = (uiop:process-info-output proc)
                 for line = (read-line out nil nil)
                 while line
                 when (funcall trigger line) do (sento.actor:tell actor '(:refresh)))
         (error () nil)))
     :name "pine-source-reader")
    (make-source :actor actor :process proc)))

(defun start-poll (system interval refresh-fn)
  "Run REFRESH-FN every INTERVAL seconds on the source actor, driven by the
actor system's wheel-timer (the timer thread only tells the actor)."
  (let ((actor (%actor system refresh-fn)))
    (sento.actor:tell actor '(:poll))
    (sento.wheel-timer:schedule-recurring
     (sento.actor-system::scheduler system) interval interval
     (lambda () (sento.actor:tell actor '(:poll))))
    (make-source :actor actor)))

;;; source registry + declarative definition

(defvar *source-defs* (make-hash-table :test 'eq)
  "name -> starter function of the actor system.")
(defvar *running* nil)

(defmacro defsource (name (system) &body body)
  "Define a source NAME. BODY, with SYSTEM bound to the actor system, starts it
and returns a source (usually via start-stream / start-poll)."
  `(setf (gethash ',name *source-defs*) (lambda (,system) ,@body)))

(defmacro defpoll (name interval &body body)
  "Reactive cell NAME refreshed to (progn BODY) every INTERVAL seconds."
  `(defsource ,name (system)
     (let ((c (cell-of ',name)))
       (start-poll system ,interval
                   (lambda () (pine.cell:set-cell c (progn ,@body)))))))

(defmacro deflisten (name command (line) &body body)
  "Reactive cell NAME fed from COMMAND's stdout: each LINE sets it to (progn
BODY) when that is non-nil."
  (let ((val (gensym)))
    `(defsource ,name (system)
       (let ((c (cell-of ',name)))
         (start-stream system ,command
           (constantly nil)
           (lambda (,line)
             (let ((,val (progn ,@body)))
               (when ,val (pine.cell:set-cell c ,val)) nil)))))))

(defun start-sources (system)
  "Start every declared source once."
  (unless *running*
    (setf *running*
          (loop for starter being the hash-values of *source-defs*
                for s = (ignore-errors (funcall starter system))
                when s collect s))))

(defun stop-sources ()
  "Terminate each source's subprocess so its reader exits; actors and timers die
with the actor system."
  (dolist (s *running*)
    (when (source-process s)
      (ignore-errors (uiop:terminate-process (source-process s) :urgent t))))
  (setf *running* nil))

;;;; The built-in sources, declared with the sugar above.

(defun workspaces ()
  "niri workspaces as (:idx N :focused BOOL :urgent BOOL), sorted by idx."
  (sort (map 'list
             (lambda (w) (list :idx (gethash "idx" w)
                               :focused (gethash "is_focused" w)
                               :urgent (gethash "is_urgent" w)))
             (com.inuoe.jzon:parse (sh "niri" "msg" "--json" "workspaces")))
        #'< :key (lambda (p) (getf p :idx))))

(defsource :workspaces (system)
  (start-stream system "niri msg --json event-stream"
    (lambda () (set! :workspaces (workspaces)))
    (lambda (line) (search "Workspace" line))))

(defun audio-volume ()
  (let ((n (%first-number (sh "wpctl" "get-volume" "@DEFAULT_AUDIO_SINK@"))))
    (if (numberp n) (round (* 100 n)) 0)))

(defun audio-muted ()
  (and (search "MUTED" (sh "wpctl" "get-volume" "@DEFAULT_AUDIO_SINK@")) t))

(defsource :audio (system)
  (start-stream system "pactl subscribe"
    (lambda () (set! :vol (audio-volume)) (set! :muted (audio-muted)))
    (lambda (line) (search "sink" line))))

(defun brightness ()
  (let ((dir (first (ignore-errors (directory "/sys/class/backlight/*/")))))
    (if dir
        (let ((cur (read-int-file (merge-pathnames "brightness" dir)))
              (mx  (read-int-file (merge-pathnames "max_brightness" dir))))
          (if (and cur mx (plusp mx)) (round (* 100 cur) mx) 50))
        50)))

(defpoll :bri 15 (brightness))

;;;; Network (nmcli). The wifi list, connection status, and the currently
;;;; selected network's actions all live in cells. select! / act! are the
;;;; in-process closures the panel's rows and buttons call -- pine's answer to
;;;; the eww nREPL callbacks: they mutate cells and shell nmcli directly.

(defun %split (s ch &optional limit)
  "Split S on CH into at most LIMIT parts (the last keeps any remaining CH)."
  (let ((parts nil) (start 0) (n 0))
    (dotimes (i (length s))
      (when (and (char= (char s i) ch) (or (null limit) (< (1+ n) limit)))
        (push (subseq s start i) parts) (setf start (1+ i)) (incf n)))
    (push (subseq s start) parts)
    (nreverse parts)))

(defun %lines (s) (remove "" (%split s #\newline) :test #'string=))
(defun cell-val (name) (let ((c (pine.cell:find-cell name))) (and c (pine.cell:cell-ref c))))

(defun net-connected ()
  (dolist (line (%lines (sh "nmcli" "-t" "-f" "TYPE,STATE,CONNECTION"
                            "device" "status")) "")
    (destructuring-bind (&optional type state conn) (%split line #\: 3)
      (when (and (member type '("wifi" "ethernet") :test #'equal)
                 (equal state "connected"))
        (return (or conn ""))))))

(defun sig-bucket (s) (cond ((>= s 66) "hi") ((>= s 40) "mid") (t "lo")))

(defun wifi-list (&optional (rescan "no"))
  (let ((saved (%lines (sh "nmcli" "-t" "-f" "NAME" "connection" "show")))
        (best (make-hash-table :test 'equal)))
    (dolist (line (%lines (sh "nmcli" "-t" "-f" "IN-USE,SSID,SECURITY,SIGNAL"
                              "device" "wifi" "list" "--rescan" rescan)))
      (destructuring-bind (&optional inuse ssid sec sig) (%split line #\: 4)
        (when (and ssid (plusp (length ssid)))
          (let ((signal (or (ignore-errors (parse-integer sig)) 0))
                (prev (gethash ssid best)))
            (when (or (null prev) (> signal (getf prev :signal)))
              (setf (gethash ssid best)
                    (list :ssid ssid :in_use (equal inuse "*")
                          :secure (not (member sec '("" "--") :test #'equal))
                          :saved (and (member ssid saved :test #'equal) t)
                          :signal signal)))))))
    (let ((rows (loop for v being the hash-values of best collect v)))
      (mapcar (lambda (r) (list :ssid (getf r :ssid) :in_use (getf r :in_use)
                               :secure (getf r :secure) :saved (getf r :saved)
                               :sig (sig-bucket (getf r :signal))))
              (sort rows (lambda (a b)
                           (cond ((not (eq (getf a :in_use) (getf b :in_use))) (getf a :in_use))
                                 ((not (eq (getf a :saved) (getf b :saved))) (getf a :saved))
                                 (t (string< (string-downcase (getf a :ssid))
                                             (string-downcase (getf b :ssid)))))))))))

(defun connected-ssid (rows)
  (loop for r in rows when (getf r :in_use) return (getf r :ssid)))

(defun actions-for (ssid rows)
  (let ((n (find ssid rows :key (lambda (r) (getf r :ssid)) :test #'equal)))
    (cond ((null n) nil)
          ((getf n :in_use) (list (list :label "Disconnect" :style "" :kind "disconnect")
                                  (list :label "Forget" :style "no" :kind "forget")))
          ((getf n :saved)  (list (list :label "Connect" :style "go" :kind "up")
                                  (list :label "Forget" :style "no" :kind "forget")))
          ((getf n :secure) (list (list :label "Connect" :style "go" :kind "connect-pw")))
          (t                (list (list :label "Connect" :style "go" :kind "connect"))))))

(defun push-actions (rows)
  (let* ((cur (cell-val :netsel))
         (sel (if (and cur (plusp (length cur))) cur (connected-ssid rows))))
    (set! :netsel (or sel ""))
    (set! :netactions (and sel (actions-for sel rows)))))

(defun refresh-net (&optional (rescan "no"))
  (set! :net (net-connected))
  (let ((rows (wifi-list rescan)))
    (when rows
      (set! :netlist rows)
      (push-actions rows))))

(defun select! (ssid)
  "Select network SSID: update its action set. Called from a panel row."
  (set! :netsel (or ssid ""))
  (set! :netactions (and ssid (actions-for ssid (cell-val :netlist)))))

(defun act! (kind)
  "Run action KIND on the selected network. Called from a panel button."
  (let* ((cur (cell-val :netsel))
         (ssid (and cur (plusp (length cur)) cur)))
    (when ssid
      (cond
        ((equal kind "disconnect") (sh "nmcli" "connection" "down" ssid))
        ((equal kind "up")         (sh "nmcli" "connection" "up" ssid))
        ((equal kind "forget")     (sh "nmcli" "connection" "delete" ssid))
        ((equal kind "connect")    (sh "nmcli" "device" "wifi" "connect" ssid))
        ((equal kind "connect-pw")
         (let ((pw (sh "fuzzel" "--dmenu" "--password" "--prompt"
                       (format nil "~a password: " ssid))))
           (when (plusp (length pw))
             (sh "nmcli" "device" "wifi" "connect" ssid "password" pw)))))
      (set! :netsel "")
      (refresh-net "yes"))))

(defsource :network (system)
  (start-stream system "nmcli monitor" (lambda () (refresh-net "no"))))

(defsource :network-scan (system)
  (start-poll system 15 (lambda () (refresh-net "yes"))))

;;;; Media (EMMS via the emacs daemon). Polled into a :media plist cell.

(defparameter +emms-elisp+
  "(let* ((trk (ignore-errors (emms-playlist-current-selected-track))) (playing (and (boundp 'emms-player-playing-p) emms-player-playing-p)) (paused (and (boundp 'emms-player-paused-p) emms-player-paused-p))) (if trk (json-encode (list :title (or (emms-track-get trk 'info-title) \"\") :artist (or (emms-track-get trk 'info-artist) \"\") :length (or (emms-track-get trk 'info-playing-time) 0) :pos (or (and (boundp 'emms-playing-time) emms-playing-time) 0) :status (cond (paused \"Paused\") (playing \"Playing\") (t \"Stopped\")))) \"{}\"))")

(defun %unquote-elisp (s)
  "emacsclient -e prints a Lisp string literal; strip the quotes and unescape."
  (let ((s (string-trim '(#\space #\newline) s)))
    (when (and (>= (length s) 2) (char= (char s 0) #\")
               (char= (char s (1- (length s))) #\"))
      (setf s (subseq s 1 (1- (length s)))))
    (with-output-to-string (out)
      (loop with i = 0 with n = (length s)
            while (< i n)
            do (let ((c (char s i)))
                 (if (and (char= c #\\) (< (1+ i) n))
                     (progn (write-char (char s (1+ i)) out) (incf i 2))
                     (progn (write-char c out) (incf i))))))))

(defun emms-media ()
  (let ((raw (sh "emacsclient" "-e" +emms-elisp+)))
    (when (plusp (length raw))
      (ignore-errors
        (let ((h (com.inuoe.jzon:parse (%unquote-elisp raw))))
          (list :title  (gethash "title" h "")  :artist (gethash "artist" h "")
                :status (gethash "status" h "Stopped")
                :pos    (gethash "pos" h 0)      :length (gethash "length" h 0)))))))

(defpoll :media 1 (emms-media))

;;;; System stats (cpu / ram / temp) for the control panel.

(defun %starts (s prefix)
  (and (>= (length s) (length prefix)) (string= s prefix :end1 (length prefix))))

(defun cpu-temp ()
  (let ((dirs (ignore-errors (directory "/sys/class/hwmon/*/"))))
    (dolist (d dirs 0)
      (when (member (sh "cat" (namestring (merge-pathnames "name" d)))
                    '("k10temp" "coretemp" "zenpower") :test #'equal)
        (let ((raw (read-int-file (merge-pathnames "temp1_input" d))))
          (when raw (return (round raw 1000))))))))

(defun mem-percent ()
  (let ((total 0) (avail 0))
    (dolist (line (%lines (sh "cat" "/proc/meminfo")))
      (cond ((%starts line "MemTotal:")     (setf total (or (%first-number line) 0)))
            ((%starts line "MemAvailable:") (setf avail (or (%first-number line) 0)))))
    (if (plusp total) (round (* 100 (- total avail)) total) 0)))

(defun cpu-percent ()
  (let ((load (or (%first-number (sh "cat" "/proc/loadavg")) 0))
        (ncpu (or (ignore-errors (parse-integer (sh "nproc"))) 1)))
    (min 100 (round (* 100 load) (max 1 ncpu)))))

(defpoll :sys 3 (list :cpu (cpu-percent) :ram (mem-percent) :temp (cpu-temp)))
