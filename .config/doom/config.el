;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; (setq doom-theme 'doom-one)
;; (setq doom-theme 'doom-acario-dark)
;; (setq doom-theme 'ef-trio-dark)
(setq doom-theme 'modus-vivendi-tinted)

;; Toggle between dark/light variant of current theme
(defun my/toggle-dark-light-theme ()
  "Toggle between dark and light variants of the current theme.
Supports doom-themes, ef-themes, and modus-themes.
Does nothing if no counterpart exists."
  (interactive)
  (let* ((name (symbol-name doom-theme))
         (new (cond
               ;; modus: operandi ↔ vivendi
               ((string-match "\\`\\(modus-\\)operandi\\(.*\\)\\'" name)
                (intern (concat (match-string 1 name) "vivendi" (match-string 2 name))))
               ((string-match "\\`\\(modus-\\)vivendi\\(.*\\)\\'" name)
                (intern (concat (match-string 1 name) "operandi" (match-string 2 name))))
               ;; -light ↔ -dark (doom + ef)
               ((string-suffix-p "-light" name)
                (intern (concat (string-remove-suffix "-light" name) "-dark")))
               ((string-suffix-p "-dark" name)
                (intern (concat (string-remove-suffix "-dark" name) "-light")))
               ;; no suffix → try -light
               (t
                (intern (concat name "-light"))))))
    (condition-case nil
        (progn
          (setq doom-theme new)
          (load-theme new t)
          (message "Switched to %s" new))
      (error
       (setq doom-theme (intern name))
       (message "No light/dark variant found for %s" name)))))

(map! :leader
      :desc "Toggle dark/light theme"
      "t L" #'my/toggle-dark-light-theme)

(after! doom-themes
  (custom-set-faces!
    '(font-lock-keyword-face :foreground "#e80004")))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
(load! "i3wm-config-mode.el")

(use-package! rainbow-mode
  :hook (i3wm-config-mode . rainbow-mode))

(after! i3wm-config-mode
  ;; Fix: Stop '#' from being treated as a comment-starter for the whole line
  (set-syntax-table i3wm-config-mode-syntax-table)
  (modify-syntax-entry ?# "." i3wm-config-mode-syntax-table)

  ;; Override: repaint anything inside a comment as comment face (runs last)
  (font-lock-add-keywords 'i3wm-config-mode
                          '(("^\\s-*#.*$" 0 'font-lock-comment-face t)   ; full-line comments
                            ("\\s-#.*$"   0 'font-lock-comment-face t))   ; inline comments
                          'append)

  ;; Fix exec_always and other missing keywords
  (font-lock-add-keywords 'i3wm-config-mode
                          '(("\\<\\(exec_always\\|exec\\|for_window\\|assign\\)\\>"
                             0 'font-lock-keywords-face))))

(after! rainbow-mode
  (defun my/rainbow-not-in-comment-p (&rest _)
    (save-excursion
      (goto-char (match-beginning 0))   ; ← go to where the color was found
      (beginning-of-line)
      (not (looking-at "^\\s-*#"))))
  (advice-add 'rainbow-colorize-match :before-while #'my/rainbow-not-in-comment-p))

;; Show more context in diffs
(after! magit
  (setq magit-diff-refine-hunk 'all))  ;; word-level diff highlighting

;; Full-screen magit status
(after! magit
  (setq magit-display-buffer-function
        #'magit-display-buffer-fullframe-status-v1))

(after! magit
  ;; Show submodule status in the status buffer
  (setq magit-module-sections-nested t)
  (magit-add-section-hook 'magit-status-sections-hook
                          'magit-insert-modules
                          'magit-insert-stashes
                          'append))

(after! julia-repl
  (julia-repl-set-terminal-backend 'vterm))

(after! julia-mode
  (add-hook 'julia-mode-hook
            (lambda ()
              (font-lock-add-keywords nil
                '(("\\<\\([a-zA-Z_][a-zA-Z0-9_!]*\\)\\.?(" 1 'font-lock-function-call-face prepend))
                'append)
              (font-lock-flush))
            'append))

(require 'denote)
(setq denote-directory (expand-file-name "~/Notes/")
      denote-file-type 'org
      denote-prompts '(title keywords))
(denote-rename-buffer-mode 1)

(map! :leader
      (:prefix ("n d" . "denote")
       :desc "New note"              "n" #'denote
       :desc "Open or create"        "o" #'denote-open-or-create
       :desc "Grep notes"            "g" #'denote-grep
       :desc "Insert link"           "i" #'denote-link
       :desc "Link or create"        "l" #'denote-link-or-create
       :desc "Backlinks"             "b" #'denote-backlinks
       :desc "Find backlink"         "B" #'denote-find-backlink
       :desc "Rename file"           "r" #'denote-rename-file
       :desc "Add keywords"          "k" #'denote-keywords-add
       :desc "Remove keywords"       "K" #'denote-keywords-remove
       :desc "Subdirectory note"     "s" #'denote-subdirectory))


(use-package! consult-denote
  :after denote
  :config
  (consult-denote-mode 1))

(after! org
  ;; Scan both org/ and Denote notes for agenda items
  (setq org-agenda-files '("~/org/" "~/Notes/"))

  ;; TODO workflow states
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAITING(w)" "|" "DONE(d)" "CANCELLED(c)")))

  ;; Log timestamps when tasks are completed
  (setq org-log-done 'time)

  ;; Show agenda starting from today, not Monday
  (setq org-agenda-start-on-weekday nil)

  ;; Warn about upcoming deadlines 7 days out
  (setq org-deadline-warning-days 7)

  ;; Custom agenda views
  (setq org-agenda-custom-commands
        '(("d" "Dashboard"
           ((agenda "" ((org-agenda-span 1)
                        (org-agenda-overriding-header "Today")))
            (todo "NEXT"   ((org-agenda-overriding-header "Next Actions")))
            (todo "WAITING" ((org-agenda-overriding-header "Waiting On")))))

          ("w" "Weekly Review"
           ((agenda "" ((org-agenda-span 7)))
            (todo "TODO" ((org-agenda-overriding-header "All TODOs")))
            (todo "WAITING" ((org-agenda-overriding-header "Waiting On"))))))))


(after! vterm
  (set-popup-rule! "^\\*vterm"
    :side 'right
    :size 0.4
    :select t
    :quit nil
    :ttl 0))
  (set-popup-rule! "^\\*doom:vterm-popup"
    :side 'right
    :size 0.4
    :select t
    :quit nil
    :ttl 0))
