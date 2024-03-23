;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Tim Perkins"
      user-mail-address "code@taughz.dev")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
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
(setq doom-font (font-spec :family "DejaVu Sans Mono")
      doom-variable-pitch-font (font-spec :family "DejaVu Sans"))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-tomorrow-night)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; Limit the minibuffer or echo area to one line. For good measure, limit Eldoc
;; to use one line as well. Full output can be shown with `M-x eldoc'.
(setq max-mini-window-height 1
      eldoc-echo-area-use-multiline-p nil)

;; Don't automatically continue comments. Why would you want that?
(setq +default-want-RET-continue-comments nil)

;; Don't hide my strings. Why would you want that?!
(advice-add #'+emacs-lisp-truncate-pin :override (lambda () ()))

;; Don't confirm killing of processes. Not sure why this is so hard.
(setq confirm-kill-processes nil)
(defun config--inhibit-query-on-exit ()
  (set-process-query-on-exit-flag (get-buffer-process (current-buffer)) nil))
(add-hook 'comint-exec-hook #'config--inhibit-query-on-exit)
(after! vterm (add-hook 'vterm-mode-hook #'config--inhibit-query-on-exit))

;; Use Google C++ Style
(add-hook! 'c++-mode-hook
  (google-set-c-style))

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/Org/")

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
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

;; Better for multi-monitor coding
(map! "C-x o" #'next-window-any-frame
      "C-x C-o" #'previous-window-any-frame)

;; Better home and end keys
(map! [home] #'doom/backward-to-bol-or-indent
      "C-a" #'doom/backward-to-bol-or-indent
      [end] #'end-of-line
      "C-e" #'end-of-line)

;; Add alternate key for redo
(map! (:after undo-fu
       :map undo-fu-mode-map
       "C-?" #'undo-fu-only-redo))

;; Use function keys for common utilities
(map! "<f1>" #'+vterm/toggle
      "<f2>" #'+default/search-other-cwd
      "<f3>" #'+default/search-project
      "<f4>" nil
      "<f5>" nil
      "<f6>" #'magit-dispatch
      "<f7>" #'magit-status
      "<f8>" #'magit-blame-addition
      "<f9>" #'magit-log-current
      "<f10>" #'magit-log-buffer-file
      "<f11>" nil
      "<f12>" nil)

;; Map the above again for VTerm
(map! :after vterm
      :map vterm-mode-map
      "<f1>" #'+vterm/toggle
      "<f2>" #'+default/search-other-cwd
      "<f3>" #'+default/search-project
      "<f4>" nil
      "<f5>" nil
      "<f6>" #'magit-dispatch
      "<f7>" #'magit-status
      "<f8>" #'magit-blame-addition
      "<f9>" #'magit-log-current
      "<f10>" #'magit-log-buffer-file
      "<f11>" nil
      "<f12>" nil)
