#!/usr/bin/env bb
;; The bar's data broker: one long-lived babashka process, run as a Guix Home
;; shepherd service (home-eww-broker). It owns every dynamic bar value in an
;; in-memory atom and pushes each into eww with `eww update', event-driven where
;; the source allows. Shepherd owns the lifecycle (single instance, respawn,
;; stop) -- no lock files or pid juggling here. eww calls back into this process
;; over an nREPL (see eww-rpc): clicking a network evals (select! ...), an action
;; button evals (act! ...). Media comes from EMMS via the emacs daemon.

(require '[babashka.process :as p]
         '[cheshire.core :as json]
         '[clojure.string :as str]
         '[clojure.java.io :as io]
         '[babashka.nrepl.server :as nrepl])

;; A shepherd service starts outside the Wayland session, so discover the
;; session sockets and hand them to every subprocess (niri msg needs
;; NIRI_SOCKET, fuzzel needs WAYLAND_DISPLAY; eww/wpctl/nmcli use XDG_RUNTIME_DIR
;; which we already inherit). Resolved per call, not cached: NIRI_SOCKET carries
;; niri's pid so it changes when niri restarts, and at boot the shepherd service
;; can scan before niri has created its socket.
(defn session-env []
  (let [xdg (or (System/getenv "XDG_RUNTIME_DIR") "/run/user/1000")
        fs  (or (.listFiles (io/file xdg)) [])
        wl  (some (fn [f] (let [n (.getName f)]
                            (when (and (str/starts-with? n "wayland-")
                                       (not (str/ends-with? n ".lock"))) n)))
                  fs)
        niri (->> fs (filter #(re-matches #"niri\..*\.sock" (.getName %)))
                  (sort-by #(.lastModified %)) last)]
    (cond-> {}
      wl   (assoc "WAYLAND_DISPLAY" wl)
      niri (assoc "NIRI_SOCKET" (.getAbsolutePath niri)))))

(defn sh [& args]
  (try (str/trim (:out (apply p/sh {:extra-env (session-env)} args))) (catch Exception _ "")))

(defn log!
  "Write to stdout, which shepherd captures to the service log-file. Flush so
  `herd' + the log are the live diagnostic surface (no pid/nrepl poking needed)."
  [& xs]
  (apply println xs) (flush))

(def state (atom {}))

(defn eww-up? []
  (try (zero? (:exit (p/sh {:extra-env (session-env) :out :string :err :string} "eww" "ping")))
       (catch Exception _ false)))

(defn eww-set!
  "eww update NAME=S; true on success. Records into @state only on success so a
  failed push (eww not ready / vars reset by reload) is retried, not skipped."
  [k s]
  (when (not= s (get @state k))
    (when (try (zero? (:exit (p/sh {:extra-env (session-env) :out :string :err :string}
                                   "eww" "update" (str (name k) "=" s))))
               (catch Exception _ false))
      (swap! state assoc k s))))

(defn put!
  "Set eww var K to V (JSON), only when changed -- re-pushing an identical value
  makes eww re-render and drop e.g. a hovered row."
  [k v]
  (eww-set! k (json/generate-string v)))

(defn put-raw! [k s] (eww-set! k s))

(defn resync! []
  (when (seq @state)
    (try (apply p/sh {:extra-env (session-env)} "eww" "update"
                (for [[k s] @state] (str (name k) "=" s)))
         (catch Exception _ nil))))

;; --- audio (pipewire) -----------------------------------------------------

(defn volume []
  (let [m (re-find #"[0-9]*\.[0-9]+" (sh "wpctl" "get-volume" "@DEFAULT_AUDIO_SINK@"))]
    (if m (int (Math/round (* 100 (Double/parseDouble m)))) 0)))

(defn muted? [] (str/includes? (sh "wpctl" "get-volume" "@DEFAULT_AUDIO_SINK@") "MUTED"))

(defn network []
  (or (some (fn [line]
              (let [[type st conn] (str/split line #":")]
                (when (and (#{"wifi" "ethernet"} type) (= st "connected")) conn)))
            (str/split-lines
             (sh "nmcli" "-t" "-f" "TYPE,STATE,CONNECTION" "device" "status")))
      ""))

(def last-temp (atom 0))

(defn cpu-temp
  "CPU temperature in whole degrees C -- a single package sensor (k10temp/
  coretemp), else the hottest hwmon. One level into /sys/class/hwmon (never
  file-seq, which follows hwmon symlinks deep into sysfs and hangs). Caches the
  last good value so a transient miss never drops it to 0."
  []
  (let [hwmons (or (.listFiles (io/file "/sys/class/hwmon")) [])
        read-t (fn [f] (try (Long/parseLong (str/trim (slurp f))) (catch Exception _ nil)))
        name-of (fn [d] (try (str/trim (slurp (io/file d "name"))) (catch Exception _ "")))
        cpu-dir (some (fn [d] (when (#{"k10temp" "coretemp" "zenpower"} (name-of d)) d)) hwmons)
        t1 (some-> cpu-dir (io/file "temp1_input") read-t)
        vals (->> hwmons
                  (mapcat (fn [d] (filter #(re-matches #"temp\d+_input" (.getName %))
                                          (or (.listFiles d) []))))
                  (keep read-t))
        t (cond t1 (int (/ t1 1000))
                (seq vals) (int (/ (apply max vals) 1000))
                :else nil)]
    (if (and t (pos? t)) (do (reset! last-temp t) t) @last-temp)))

(defn push-sys! []
  (put! :sys {:vol (volume) :muted (muted?) :net (network) :temp (cpu-temp)}))

(defn sinks []
  (let [default (sh "pactl" "get-default-sink")]
    (->> (str/split (sh "pactl" "list" "sinks") #"(?m)^Sink #")
         (remove str/blank?)
         (keep (fn [block]
                 (let [name (some-> (re-find #"(?m)^\s*Name:\s*(.+)$" block) second str/trim)
                       desc (some-> (re-find #"(?m)^\s*Description:\s*(.+)$" block) second str/trim)]
                   (when name {:name name :desc (or desc name) :default (= name default)}))))
         vec)))

(defn push-sinks! [] (put! :sinks (sinks)))

;; --- network (nmcli) ------------------------------------------------------

(defn sig-bucket [s] (cond (>= s 66) "hi" (>= s 40) "mid" :else "lo"))

(defn wifi-list [mode]
  (let [saved (into #{} (remove str/blank?
                                (str/split-lines (sh "nmcli" "-t" "-f" "NAME" "connection" "show"))))
        rows (->> (str/split-lines
                   (sh "nmcli" "-t" "-f" "IN-USE,SSID,SECURITY,SIGNAL"
                       "device" "wifi" "list" "--rescan" mode))
                  (remove str/blank?)
                  (map (fn [line]
                         (let [[inuse ssid sec sig] (str/split line #":" 4)]
                           {:ssid ssid
                            :in_use (= inuse "*")
                            :secure (not (contains? #{"" "--" nil} sec))
                            :saved (contains? saved ssid)
                            :signal (try (Integer/parseInt (str/trim (or sig "0")))
                                         (catch Exception _ 0))})))
                  (remove #(str/blank? (:ssid %))))
        uniq (vals (reduce (fn [m n]
                             (if-let [e (get m (:ssid n))]
                               (if (> (:signal n) (:signal e)) (assoc m (:ssid n) n) m)
                               (assoc m (:ssid n) n)))
                           {} rows))]
    ;; stable order (connected, saved, alpha) + bucketed signal so the row value
    ;; doesn't change every scan (which would re-render and break hover)
    (->> uniq
         (sort-by (juxt (complement :in_use) (complement :saved) (comp str/lower-case :ssid)))
         (mapv (fn [n] (-> n (assoc :sig (sig-bucket (:signal n))) (dissoc :signal)))))))

(def netcache (atom {}))
(def selected (atom nil))
(def last-conn (atom :init))

(defn connected-ssid [] (some (fn [[k v]] (when (:in_use v) k)) @netcache))

(defn actions-for [ssid]
  (let [n (get @netcache ssid)
        a (fn [label style kind] {:label label :style style :kind kind})]
    (cond
      (nil? n)    []
      (:in_use n) [(a "Disconnect" ""   "disconnect") (a "Forget" "no" "forget")]
      (:saved n)  [(a "Connect"    "go" "up")         (a "Forget" "no" "forget")]
      (:secure n) [(a "Connect"    "go" "connect-pw")]
      :else       [(a "Connect"    "go" "connect")])))

(defn push-netactions! []
  (let [sel (or @selected (connected-ssid))]
    (put-raw! :netsel (or sel ""))
    (put! :netactions (if sel (actions-for sel) []))))

(defn push-netlist!
  ([] (push-netlist! "no"))
  ([mode]
   (let [rows (wifi-list mode)]
     ;; never clobber a good list with an empty read (nmcli hiccup / collapsed cache)
     (when (seq rows)
       (reset! netcache (into {} (map (juxt :ssid identity) rows)))
       (put! :netlist rows)
       (let [c (connected-ssid)]
         (when (not= c @last-conn) (reset! last-conn c) (reset! selected nil)))
       (push-netactions!)))))

;; nREPL entry points: eww calls these via eww-rpc
(defn select! [ssid]
  (log! "select!" (pr-str ssid))
  (reset! selected (when (seq ssid) ssid))
  (push-netactions!))

(defn act! [kind]
  (log! "act!" (pr-str kind) "ssid" (pr-str (or @selected (connected-ssid))))
  (when-let [ssid (or @selected (connected-ssid))]
    (try
      (case kind
        "disconnect" (p/sh {:extra-env (session-env)} "nmcli" "connection" "down" ssid)
        "up"         (p/sh {:extra-env (session-env)} "nmcli" "connection" "up" ssid)
        "forget"     (p/sh {:extra-env (session-env)} "nmcli" "connection" "delete" ssid)
        "connect"    (p/sh {:extra-env (session-env)} "nmcli" "device" "wifi" "connect" ssid)
        "connect-pw" (let [pw (sh "fuzzel" "--dmenu" "--password" "--prompt"
                                  (str ssid " password: "))]
                       (when (seq pw)
                         (p/sh {:extra-env (session-env)}
                               "nmcli" "device" "wifi" "connect" ssid "password" pw)))
        nil)
      (catch Exception e (log! "act!" kind "failed:" (str e))))
    (reset! selected nil)
    (push-netlist!)))

;; --- brightness -----------------------------------------------------------

(defn brightness []
  (let [d (first (filter #(.isDirectory %)
                         (or (.listFiles (io/file "/sys/class/backlight")) [])))]
    (if d
      (let [cur (Long/parseLong (str/trim (slurp (io/file d "brightness"))))
            mx  (Long/parseLong (str/trim (slurp (io/file d "max_brightness"))))]
        (int (Math/round (* 100.0 (/ cur mx)))))
      (let [f (str/split (sh "ddcutil" "getvcp" "10" "--brief") #"\s+")]
        (if (>= (count f) 5)
          (int (Math/round (* 100.0 (/ (Double/parseDouble (nth f 3))
                                       (Double/parseDouble (nth f 4))))))
          50)))))

(defn push-bri! [] (put! :bri (brightness)))

;; --- workspaces / window title (niri) -------------------------------------

(defn workspaces []
  (->> (json/parse-string (:out (p/sh {:extra-env (session-env)} "niri" "msg" "--json" "workspaces")) true)
       (sort-by :idx)
       (mapv #(select-keys % [:idx :id :is_focused :is_urgent]))))

(defn push-workspaces! [] (put! :workspaces (workspaces)))

(defn focused-title []
  (let [w (try (json/parse-string
                (:out (p/sh {:extra-env (session-env)} "niri" "msg" "--json" "focused-window")) true)
               (catch Exception _ nil))]
    (or (:title w) "")))

(defn push-wintitle! []
  (let [t (focused-title)]
    (when (seq t) (put-raw! :wintitle t))))

;; --- media (EMMS via the emacs daemon) ------------------------------------

(def emms-elisp
  "(let* ((trk (ignore-errors (emms-playlist-current-selected-track)))
          (playing (and (boundp 'emms-player-playing-p) emms-player-playing-p))
          (paused  (and (boundp 'emms-player-paused-p) emms-player-paused-p)))
     (if trk
         (json-encode
          (list :title  (or (emms-track-get trk 'info-title)
                            (ignore-errors (file-name-base (emms-track-name trk))) \"\")
                :artist (or (emms-track-get trk 'info-artist) \"\")
                :length (or (emms-track-get trk 'info-playing-time) 0)
                :pos    (or (and (boundp 'emms-playing-time) emms-playing-time) 0)
                :file   (or (ignore-errors (emms-track-name trk)) \"\")
                :status (cond (paused \"Paused\") (playing \"Playing\") (t \"Stopped\"))))
       \"{}\"))")

(defn unquote-elisp [s]
  (-> (str/trim s)
      (str/replace #"^\"" "") (str/replace #"\"$" "")
      (str/replace "\\\"" "\"") (str/replace "\\\\" "\\")))

(def media-default
  {:title "" :artist "" :status "Stopped" :length 0 :pos 0
   :file "" :art "" :posStr "0:00" :lenStr "0:00"})

(defn mmss [s] (let [s (int (or s 0))] (format "%d:%02d" (quot s 60) (rem s 60))))

(def art-cache-dir
  (let [d (io/file (or (System/getenv "XDG_CACHE_HOME")
                       (str (System/getenv "HOME") "/.cache"))
                   "eww-media-art")]
    (.mkdirs d) d))

(defn embedded-art
  "Extract the track's embedded cover art to a cached file via ffmpeg, keyed by
  path. A .none marker records misses so the 1s poll never re-runs ffmpeg on a
  track that has no embedded art."
  [file]
  (let [key  (format "%08x" (hash file))
        jpg  (io/file art-cache-dir (str key ".jpg"))
        none (io/file art-cache-dir (str key ".none"))]
    (cond
      (.exists jpg)  (str "file://" (.getAbsolutePath jpg))
      (.exists none) nil
      :else
      (let [r (try (p/sh "ffmpeg" "-y" "-loglevel" "quiet" "-i" file
                         "-an" "-vcodec" "copy" (.getAbsolutePath jpg))
                   (catch Exception _ {:exit 1}))]
        (if (and (zero? (:exit r)) (.exists jpg) (pos? (.length jpg)))
          (str "file://" (.getAbsolutePath jpg))
          (do (.delete jpg) (spit none "") nil))))))

(defn cover-for [file]
  (try
    (when (seq file)
      (let [dir    (.getParentFile (io/file file))
            cover? #{"cover.jpg" "cover.jpeg" "cover.png"
                     "folder.jpg" "folder.jpeg" "folder.png"
                     "front.jpg" "front.jpeg" "front.png"}]
        (or (when (and dir (.isDirectory dir))
              (some (fn [f] (when (cover? (str/lower-case (.getName f)))
                              (str "file://" (.getAbsolutePath f))))
                    (.listFiles dir)))
            (embedded-art file))))
    (catch Exception _ nil)))

(defn media []
  (let [raw (sh "timeout" "2" "emacsclient" "-e" emms-elisp)
        m   (if (str/blank? raw)
              media-default
              (merge media-default
                     (try (json/parse-string (unquote-elisp raw) true)
                          (catch Exception _ {}))))]
    (assoc m :art (or (cover-for (:file m)) "")
             :posStr (mmss (:pos m)) :lenStr (mmss (:length m)))))

(defn push-media! [] (put! :media (media)))

;; --- event loops ----------------------------------------------------------

(defn lines! [cmd on-line]
  (let [proc (p/process cmd {:out :stream :err :inherit :extra-env (session-env)})]
    (with-open [rdr (io/reader (:out proc))]
      (doseq [line (line-seq rdr)] (on-line line)))))

(defn niri-thread []
  (push-workspaces!) (push-wintitle!)
  (lines! ["niri" "msg" "--json" "event-stream"]
          (fn [line]
            (when (str/includes? line "Workspace") (push-workspaces!))
            (when (str/includes? line "Window") (push-wintitle!)))))

(defn audio-thread []
  (push-sys!) (push-sinks!)
  (lines! ["pactl" "subscribe"]
          (fn [line] (when (re-find #"sink|server|source" line) (push-sys!) (push-sinks!)))))

(defn net-thread []
  ;; only the header status here; the wifi-thread owns netlist (forced rescan,
  ;; every 15s) so monitor-event floods can't clobber the list with cheap reads
  (push-sys!)
  (lines! ["nmcli" "monitor"] (fn [_] (push-sys!))))

(defn media-thread [] (loop [] (push-media!) (Thread/sleep 1000) (recur)))

(defn slow-thread []
  (loop [] (push-bri!) (push-sys!) (Thread/sleep 15000) (recur)))

(defn wifi-thread []
  ;; NM ages its BSS list down to just the connected AP when wifi is idle, and a
  ;; single forced scan after that returns only that AP -- it takes a few scans
  ;; to fill. So scan fast (3s) while the list is collapsed (login warmup, or a
  ;; later age-out) and settle to 15s once it's populated. "list --rescan yes"
  ;; forces the scan inside the read; cheap monitor reads use --rescan no.
  (loop []
    (push-netlist! "yes")
    (let [n (count @netcache)]
      (log! "wifi:" n "networks")
      (Thread/sleep (if (<= n 1) 3000 15000)))
    (recur)))

;; --- main -----------------------------------------------------------------

(nrepl/start-server! {:host "127.0.0.1" :port 1667})
(log! "eww-broker started; session-env" (pr-str (session-env)) "; nREPL 127.0.0.1:1667")
(loop [] (when-not (eww-up?) (Thread/sleep 500) (recur)))
(log! "eww connected; starting sources")
(resync!)

(future (niri-thread))
(future (audio-thread))
(future (net-thread))
(future (media-thread))
(future (slow-thread))
(future (wifi-thread))

;; resync only when eww comes back from a restart (it drops its vars then);
;; shepherd owns our lifecycle, so no exit/lock logic here.
(loop [up? true]
  (Thread/sleep 1000)
  (let [now (eww-up?)]
    (when (and now (not up?)) (resync!))
    (recur now)))
