(asdf:defsystem #:pine
  :description "Pine Is Not Emacs"
  :author "Bret Horne"
  :license "MIT"
  :version "0.0.1"
  :depends-on (#:sento
               #:sento-remoting
               #:fset
               #:alexandria
               #:bordeaux-threads
               #:closer-mop
               #:cffi
               #:cffi-libffi
               #:com.inuoe.jzon
               #:pine/vt)
  :serial t
  :pathname "src/"
  :components
  ((:file "package")
   (:file "key")
   (:file "keymap")
   (:file "server")
   (:file "eval")
   (:file "actor")
   (:file "event")
   (:file "hooks")
   (:file "face")
   (:file "buffer")
   (:file "window")
   (:file "client")
   (:file "cell")
   (:file "sources")
   (:file "echo")
   (:file "command")
   (:file "variable")
   (:file "layout")
   (:file "mode")
   (:file "kill-ring")
   (:file "complete")
   (:file "prompt")
   (:file "file")
   (:file "repl")
   (:file "term")
   (:file "ts")
   (:file "render")
   (:file "editor")
   (:file "user")
   (:file "main")))

(asdf:defsystem #:pine/vt
  :description "Self-contained terminal emulator (ex hemlock.term) + native pty."
  :depends-on (#:cffi)
  :serial t
  :pathname "vt/"
  :components ((:file "package")
               (:file "types")
               (:file "color")
               (:file "sgr")
               (:file "ops")
               (:file "write")
               (:file "parser")
               (:file "render")
               (:file "input")
               (:file "pty")))

(asdf:defsystem #:pine/gtk
  :depends-on (#:pine #:cl-gtk4 #:cl-gdk4 #:cl-cairo2)
  :serial t
  :pathname "src/"
  :components ((:file "surface")
               (:file "de")
               (:file "gtk")))
