#!/usr/bin/env bb
;; Window switcher: list niri windows, pick one through fuzzel, focus it (which
;; also jumps to its workspace)

(require '[babashka.process :as p]
         '[cheshire.core :as json]
         '[clojure.string :as str])

(def windows
  (json/parse-string (:out (p/sh "niri" "msg" "--json" "windows")) true))

(def lines
  (->> windows
       (map (fn [w]
              (format "%s\t[ws %s]  %s  ·  %s"
                      (:id w)
                      (:workspace_id w)
                      (or (not-empty (:title w)) "(untitled)")
                      (or (:app_id w) ""))))
       (str/join "\n")))

;; Show column 2 (the readable label); fuzzel returns column 1 (the id).
(def id
  (str/trim
   (:out (p/sh {:in lines}
               "fuzzel" "--dmenu" "--with-nth" "2" "--accept-nth" "1"
               "--prompt" "window: "))))

(when (not (str/blank? id))
  (p/sh "niri" "msg" "action" "focus-window" "--id" id))
