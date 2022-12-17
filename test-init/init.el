;;; init.el --- Initialization file -*- lexical-binding: t; -*-

;;; Commentary:

;;; Code:

;; Some basic settings

(fset 'yes-or-no-p 'y-or-n-p)
(setq mouse-wheel-progressive-speed nil)
(setq mouse-wheel-scroll-amount '(3))
(pixel-scroll-precision-mode)
(setq scroll-preserve-screen-position 1)
(set-language-environment "UTF-8")
(setq default-input-method "TeX")
(setq make-backup-files nil
      auto-save-default nil
      create-lockfiles nil)
(global-auto-revert-mode t)
(delete-selection-mode 1)
(setq user-full-name "Benjamin Ide"
      user-mail-address "ben@bencide.com")
(setq browse-url-browser-function 'browse-url-firefox)
(setq help-window-select t)
(setq sentence-end-double-space nil)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))


;; Bootstrap desired package system (elpaca or straight)

(require 'bootstrap-elpaca)


;; Theme

;; (elpaca-use-package ef-themes
;;   :config (load-theme 'ef-bio))

(load-theme 'modus-vivendi)


;; Packages

(elpaca-use-package diminish)
(elpaca-use-package vterm :ensure nil)


;;; keybindings

(elpaca-use-package evil
  :demand t
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-respect-visual-line-mode t)
  :config (evil-mode 1))

(elpaca-use-package evil-collection
  :demand t
  :after evil
  :config
  (evil-collection-init))

(elpaca-use-package evil-commentary
  :demand t
  :after evil
  :diminish evil-commentary-mode
  :config (evil-commentary-mode))

(elpaca-use-package evil-surround
  :demand t
  :after evil
  :diminish evil-surround-mode
  :config (global-evil-surround-mode 1))

;;; init.el ends here
