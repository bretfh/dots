  (use-package org
    :mode ("\\.org\\'" . org-mode)
    :config
    (setq org-directory "~/.emacs.d/org")
    (setq org-agenda-files '("~/.emacs.d/org"))
    (setq org-default-notes-file (concat org-directory "/.org"))
    (setq org-refile-targets '((org-agenda-files :maxlevel . 3)))
    (setq org-agenda-restore-windows-after-quit t)   
    (setq org-hide-emphasis-markers t)      	      
    (setq org-catch-invisible-edits 'show-and-error) 
    (setq org-startup-indented t)		      

    (setq org-edit-src-content-indentation 0
          org-src-tab-acts-natively t
          org-src-fontify-natively t)

    (setq org-confirm-babel-evaluate nil)
    (org-babel-do-load-languages 'org-babel-load-languages
                                 '((shell . t)
                                   (emacs-lisp . t)
                                   (clojure . t)))
    (setq org-babel-clojure-backend 'cider)

    (define-key global-map "\C-ca" 'org-agenda)
    (define-key global-map "\C-cc" 'org-capture)
    (define-key global-map "\C-cr" 'org-refile)

    (setq org-todo-keywords
          '((sequence "TODO(t!)" "IN-PROGRESS(p!)" "WAITING(w@/!)" "|" "DONE(d!)")
            (sequence "|" "CANCELLED(c@/!)" "DELEGATED(e@/!)" "SOMEDAY(s@/!)")))

    (setq org-capture-templates
          '(("t" "Todo" entry (file "~/.emacs.d/org/Tasks.org")
             "* TODO %?" :empty-lines 1)
            ("j" "Journal" entry (file+olp+datetree "~/.emacs.d/org/Journal.org")
             "* %?\nEntered on: %<%r>" :tree week)
            ("h" "Habit" entry (file "~/.emacs.d/org/Habits.org")
             "* TODO %?\nSCHEDULED: %(format-time-string \"%<<%Y-%m-%d %a .+2d/3d>>\")\n:PROPERTIES:\n:STYLE: habit\n:END:")))

    (setq org-tag-persistent-alist '(("Leisure" . ?l)("Moderate" . ?m) ("Urgent" . ?u)
                                     (:newline . nil)
                                     ("Work" . ?w) ("Personal" . ?p)
                                     (:newline . nil)
                                     ("Practice" . ?P) ("Read" . ?r))))


(provide 'rez-notes)
