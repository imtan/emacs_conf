;;; init.el --- Initialization file for Emacs
;;; Code:
(set-locale-environment "ja_JP.UTF-8")
(setq mac-option-modifier 'meta)
(setq visible-bell 1)
;; 環境を日本語、UTF-8にする
(set-locale-environment nil)
(set-language-environment "Japanese")
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-buffer-file-coding-system 'utf-8)
(setq default-buffer-file-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)
(require 'url)
(require 'json)
(setq x-select-enable-clipboard t)
;; Linear APIキーは環境変数またはauth-sourceから取得
;; 環境変数を設定: export LINEAR_API_KEY="your-key-here"
;; または ~/.authinfo.gpg に: machine api.linear.app login user password your-key-here
(defvar linear-api-key
  (or (getenv "LINEAR_API_KEY")
      (auth-source-pick-first-password :host "api.linear.app"))
  "Your Linearapp API Key.")
(defvar linear-api-endpoint "https://api.linear.app/graphql" "Linearapp API Endpoint.")

(defun fetch-linear-tasks ()
  (interactive)
  (let ((url-request-method "POST")
        (url-request-extra-headers `(("Content-Type" . "application/json")
                                     ("Authorization" . ,linear-api-key))) ; Bearerプレフィックスを取り除きます
        (url-request-data (json-encode `((query . "query { issues { nodes { id title } } }")))))
    (url-retrieve linear-api-endpoint (lambda (_status)
                                        ;; 新しいバッファを作成して表示
                                        (let* ((buffer (generate-new-buffer "*Linear Tasks*")))
                                          (switch-to-buffer buffer)
                                          (set-buffer-multibyte t) ; マルチバイト文字（日本語など）を扱うための設定
                                          (goto-char url-http-end-of-headers)
                                          (let* ((json-object-type 'hash-table)
                                                 (json-array-type 'list)
                                                 (json-key-type 'string)
                                                 (json (json-read))
                                                 (tasks (gethash "nodes" (gethash "issues" (gethash "data" json)))))
                                            ;; タスクのタイトルをバッファに表示
                                            (dolist (task tasks)
                                              (let ((title (gethash "title" task)))
                                                (insert (format "Title: %s\n" title))))
                                            (display-buffer buffer))))))) ; display-bufferを追加してバッファを表示

(setq org-agenda-files
      '("~/Dropbox/Org/capture/tasks.org"))
(setq org-agenda-use-time-grid t)
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(use-package exec-path-from-shell
  :straight t
  :ensure t
  :init (exec-path-from-shell-initialize))

(when (memq window-system '(mac ns x))
  (exec-path-from-shell-copy-env  "OPENAI_API_KEY")
  (exec-path-from-shell-initialize))

(straight-use-package 'org)

(when (equal system-type 'gnu/linux)
  (load-file "~/.emacs.d/init-linux.el"))

					; (when (equal system-type 'darwin)
					;   (load-file "~/.emacs.d/init-osx.el"))

(global-set-key (kbd "C-c ,") (lambda() (interactive) (find-file "~/.emacs.d/init.el")))

;; use-package with Elpaca:

(setq find-file-visit-truename t)
;;; *.~ とかのバックアップファイルを作らない
(setq make-backup-files nil)
;;; .#* とかのバックアップファイルを作らない
(setq auto-save-default nil)
(menu-bar-mode 0)
(tool-bar-mode 0)

(add-to-list 'custom-theme-load-path "~/.emacs.d/themes")
(add-to-list 'load-path "~/.emacs.d/site-lisp/emacs-application-framework/")
(setq custom-theme-directory "~/.emacs.d/themes")
(define-key global-map (kbd "C-c a") 'org-agenda)

(load-theme 'modus-vivendi t)
(straight-use-package 'recentf-ext)
(recentf-mode 1)
(setq recentf-max-saved-items 200)
(setq recentf-save-file "~/.emacs.d/recentf")
(setq recentf-auto-cleanup 'never)
(use-package quelpa
  :straight t
  :ensure t)
(use-package quelpa-use-package
  :straight t
  :ensure t)


(use-package emacs-conflict
  :straight (emacs-conflict :type git :host github :repo "ibizaman/emacs-conflict" :branch "master")
  :bind ("C-c r r" . emacs-conflict-resolve-conflicts))

(straight-use-package 'company)
(global-company-mode)
(setq company-transformers '(company-sort-by-backend-importance))
(setq company-idle-delay 0)
(setq company-minimum-prefix-length 3)
(setq company-selection-wrap-around t)
(setq completion-ignore-case t)
(setq company-dabbrev-downcase nil)
(global-set-key (kbd "C-M-i") 'company-complete)
(define-key company-active-map (kbd "C-n") 'company-select-next)
(define-key company-active-map (kbd "C-p") 'company-select-previous)
(define-key company-active-map (kbd "C-s") 'company-filter-candidates)
(define-key company-active-map (kbd "C-i") 'company-complete-selection)
(define-key company-active-map [tab] 'company-complete-selection)
(define-key company-active-map (kbd "C-f") 'company-complete-selection)
(define-key company-active-map (kbd "C-h") 'nil)
(define-key emacs-lisp-mode-map (kbd "C-M-i") 'company-complete)
(use-package org-roam
  :ensure t
  :straight t
  :custom
  (org-roam-db-location "~/Documents/Org/org-roam.db")
  (org-roam-directory (file-truename "~/Dropbox/Org"))
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n g" . org-roam-graph)
         ("C-c n i" . org-roam-node-insert)
         ("C-c n c" . org-roam-capture)
         ;; Dailies
         ("C-c n j" . org-roam-dailies-capture-today)
	 ("C-c n t" . org-roam-tag-add))
  :config
  ;; If you're using a vertical completion framework, you might want a more informative completion interface
  (setq org-roam-node-display-template (concat "${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
  (org-roam-db-autosync-mode)
  ;; If using org-roam-protocol
  (require 'org-roam-protocol))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("df782d1d31bc53de4034dacf7dbf574bf7513df8104486738a9b425693451eba"
     default))
 '(lsp-nim-langserver "nimlangserver")
 '(lsp-nim-lsp "~/.nimble/bin/nimlsp")
 '(org-agenda-span 'day)
 '(org-display-custom-times t)
 '(org-modules
   '(ol-bbdb ol-bibtex ol-docview ol-doi ol-eww ol-gnus ol-info ol-irc
	     ol-mhe ol-rmail org-tempo ol-w3m))
 '(org-startup-indented t)
 '(org-timestamp-custom-formats '("<%Y年%m月%d日(%a)>" . "<%Y年%m月%d日(%a)%H時%M分>"))
 '(warning-suppress-log-types
   '((use-package) (use-package) ((org-element org-element-parser)))))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
(use-package markdown-mode
  :straight t
  :ensure t
  :mode ("\\.md\\'" . gfm-mode))

(use-package org-roam-ui
  :straight
  (:host github :repo "org-roam/org-roam-ui" :branch "main" :files ("*.el" "out"))
  :after org-roam
  ;;         normally we'd recommend hooking orui after org-roam, but since org-roam does not have
  ;;         a hookable mode anymore, you're advised to pick something yourself
  ;;         if you don't care about startup time, use
  ;;  :hook (after-init . org-roam-ui-mode)
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

(use-package ivy
  :straight t
  :ensure t)

(defun insert-nerdfont-icon-with-completion ()
  "Insert a Nerd Font icon with completion."
  (interactive)
  (let ((icons '(("nf-fa-address-book" . "f2b9")
                 ("nf-fa-anchor" . "f13d")
                 ;; 他のアイコンをここに追加
                 )))
    (insert-char (string-to-number
                  (cdr (assoc (ivy-completing-read "Select icon: " icons) icons))
                  16))))

(defun insert-unicode-char (codepoint)
  "Insert a Unicode character based on a hexadecimal CODEPOINT."
  (interactive "sEnter Unicode codepoint (e.g., f101): ")
  (let ((char (string-to-number codepoint 16)))
    (if (char-displayable-p char)
        (insert-char char)
      (message "Character U+%s is not displayable in the current font." codepoint))))


(global-set-key (kbd "C-c o") 'insert-nerdfont-icon-with-completion)
(global-set-key (kbd "C-c p") 'insert-unicode-char)


(use-package org-journal
  :straight t
  :ensure t
  :defer t
  :custom
  (org-journal-dir "~/Dropbox/Org/journal")
  (org-journal-date-format "%A,%Y/%B/%d")
  :bind (("C-c j" . org-journal-new-entry)
	 ("C-c ｊ" . org-journal-new-entry)))

(setq org-use-speed-commands t)
;; org-capture
;; キーバインドの設定
(global-set-key (kbd "C-c c") 'org-capture)
(global-set-key (kbd "C-c s") 'org-schedule)
;;ファイルパスの設定
(setq work-directory "~/Dropbox/Org/capture/")
(setq taskfile (concat work-directory "tasks.org"))
(setq listfile (concat work-directory "list.org"))
(defun my-org-capture-journal-file ()
  "Generate the file name for the daily journal entry."
  (expand-file-name (concat "~/Dropbox/Org/journal/" (format-time-string "%Y%m%d"))))
(use-package neotree
  :straight t
  :ensure t)

(setq org-capture-templates
      '(;; タスク（スケジュールなし）
	("t" "タスク（スケジュールなし）" entry (file+headline taskfile "Tasks")
	 "** TODO %? \n")
	("j" "タスク（スケジュールなし）" entry (file+headline (concat "~/Dropbox/Org/journal/" (format-time-string "%Y%m%d" (current-time)) "Tasks"))
	 "** TODO %? \n")
	;; タスク（スケジュールあり）
	("s" "タスク（スケジュールあり）" entry (file+headline taskfile "Tasks")
	 "** TODO %? \n   SCHEDULED: %^t \n")
        ("l" "やりたいこと" checkitem (file+headline listfile "やりたいこと")
	 "[ ] %? \n")
        ("b" "欲しいもの" checkitem (file+headline listfile "欲しいもの")
	 "[ ] %? \n")
        ("m" "メモ" checkitem (file+headline listfile "メモ")
	 "[ ] %? \n")
        ("g" "行きたいところ" checkitem (file+headline listfile "行きたいところ")
	 "[ ] %? \n")))

(use-package markdown-mode
  :straight t
  :ensure t)

(use-package org-roam-gt
  :straight (:host github :repo "dmgerman/org-roam-gt" :branch "main" :files ("*.el"))
  :ensure t)


(use-package projectile
  :straight (:host github :repo "imtan/projectile" :branch "master" :files ("*.el" "doc"))
  :ensure t
  :bind (("C-c p" . projectile-command-map))
  :config (add-to-list 'projectile-globally-ignored-directories "node_modules")
  (add-to-list 'projectile-globally-ignored-directories "bundle")
  (add-to-list 'projectile-globally-ignored-directories "vendor"))

(use-package rainbow-delimiters
  :straight t
  :ensure t
  :init
  (add-hook 'prog-mode-hook #'rainbow-delimiters-mode))

(use-package cl-lib
  :straight t
  :ensure t)

(use-package color
  :straight t
  :ensure t)

(use-package lsp-mode
  :straight (:host github :repo "emacs-lsp/lsp-mode" :branch "master" :files ("*.el" "out"))
  :ensure t
  :bind("C-c l d . lsp-describe-thing-at-point"))

;; 必要な依存関係をインストール
(use-package websocket
  :straight t
  :ensure t)

(use-package transient
  :straight t
  :ensure t)

;; web-serverの確実なインストール
(straight-use-package 'web-server)
(use-package web-server
  :straight t
  :ensure t
  :demand t)

;; eatターミナルエミュレータ（Windows推奨）
(use-package eat
  :straight t
  :ensure t)

;; Claude Code IDE（Windows最適化設定）
(use-package claude-code-ide
  :straight (:type git :host github :repo "manzaltu/claude-code-ide.el")
  :bind (("C-c C-'" . claude-code-ide-menu)
         ("C-c C-c" . claude-code-ide)
         ("C-c C-r" . claude-code-ide-resume)
         ("C-c C-s" . claude-code-ide-stop)))

;; 追加のキーバインド
(global-set-key (kbd "C-c C-f") 'claude-code-windows-fallback)
(global-set-key (kbd "C-c C-d") 'claude-code-diagnose)
(global-set-key (kbd "C-c C-1") 'claude-code-switch-to-cmd)      ; cmd.exeに切り替え
(global-set-key (kbd "C-c C-2") 'claude-code-switch-to-cmdproxy) ; cmdproxy.exeに切り替え


(use-package nim-mode
  :straight t
  :ensure t)

(use-package google-this
  :straight t
  :ensure t
  :bind(("C-x g" . google-this-mode-submap)))

(google-this-mode 1)


(cl-loop
 for index from 1 to rainbow-delimiters-max-face-count
 do
 (let ((face (intern (format "rainbow-delimiters-depth-%d-face" index))))
   (cl-callf color-saturate-name (face-foreground face) 31)))

(global-display-line-numbers-mode)
(use-package elfeed
  :straight t
  :ensure t
  :bind ("C-x w w" . elfeed))

(use-package elfeed-org
  :straight t
  :ensure t
  :config
  (elfeed-org)
  (setq rmh-elfeed-org-files (list "~/Dropbox/Org/feeds.org")))

(use-package elfeed-dashboard)

(use-package dashboard
  :straight t
  :ensure t
  :config
  (add-hook 'elpaca-after-init-hook #'dashboard-insert-startupify-lists)
  (add-hook 'elpaca-after-init-hook #'dashboard-initialize)
  (dashboard-setup-startup-hook))

(use-package yasnippet
  :straight t
  :ensure t)
(global-unset-key "\C-h")
(global-set-key "\C-h" 'delete-backward-char)


(use-package chatgpt-shell
  :ensure t
  :straight t
  :commands (chatgpt-shell--primary-buffer chatgpt-shell chatgpt-shell-prompt-compose)
  :bind (("C-x m" . chatgpt-shell)
         ("C-c C-e" . chatgpt-shell-prompt-compose))
  :hook (chatgpt-shell-mode . (lambda () (setq-local completion-at-point-functions nil)))
  :init
  (setq shell-maker-history-path (concat user-emacs-directory "var/"))
  (add-to-list 'display-buffer-alist
	       '("\\*chatgpt\\*"
                 display-buffer-in-side-window
                 (side . right)
                 (slot . 0)
                 (window-parameters . ((no-delete-other-windows . t)))
                 (dedicated . t)))

  :bind (:map chatgpt-shell-mode-map
	      (("RET" . newline)
	       ("M-RET" . shell-maker-submit)
	       ("M-." . dictionary-lookup-definition)))
  :custom
  (shell-maker-prompt-before-killing-buffer nil)
  (chatgpt-shell-openai-key
   (auth-source-pick-first-password :host "api.openai.com"))
  (chatgpt-shell-transmitted-context-length 5)
  (chatgpt-shell-model-versions '("gpt-4" "gpt-4o-2024-05-13" "gpt-3.5-turbo-16k" "gpt-3.5-turbo"  "gpt-4-32k")))

(use-package solaire-mode
  :straight t
  :ensure t
  :init)

(use-package vertico
  :straight t
  :ensure t
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy)
  :init
  (vertico-mode)

.  ;; Different scroll margin
  ;; (setq vertico-scroll-margin 0)

  ;; Show more candidates
  ;; (setq vertico-count 20)

  ;; Grow and shrink the Vertico minibuffer
  ;; (setq vertico-resize t)

  ;; Optionally enable cycling for `vertico-next' and `vertico-previous'.
  (setq vertico-cycle t))

(use-package vertico-multiform

  :ensure nil
  :hook (after-init . vertico-multiform-mode)
  :init
  (setq vertico-multiform-commands
        '((consult-line (:not posframe))
          (gopar/consult-line (:not posframe))
          (consult-ag (:not posframe))
          (consult-grep (:not posframe))
          (consult-imenu (:not posframe))
          (xref-find-definitions (:not posframe))
	  (t posframe))))

(use-package vertico-posframe
  :straight t
  :ensure t)

(use-package writeroom-mode
  :straight t
  :ensure t)

(use-package toc-org
  :straight t
  :ensure t
  :commands toc-org-enable :init (add-hook 'org-mode-hook 'toc-org-enable))

(use-package golden-ratio
  :straight t
  :ensure t
  :init (golden-ratio-mode 1))

;; (use-package pdf-tools
;;   :straight t
;;   :ensure t
;;   :mode "\\.pdf\\'"
;;   :hook (pdf-view-mode . (lambda () (interactive) (display-line-numbers-mode -1)))
;;   :bind (:map pdf-view-mode-map
;; 	      ("j" . pdf-view-next-line-or-next-page)
;; 	      ("k" . pdf-view-previous-line-or-previous-page)
;; 	      ("C-=" . pdf-view-enlarge)
;; 	      ("C--" . pdf-view-shrink))
;;   :init (pdf-loader-install)
;;   :config (add-to-list 'revert-without-query ".pdf"))

;; 要らなければ消す
;; (add-hook 'pdf-view-mode-hook #'(lambda () (interactive) (display-line-numbers-mode -1)))

;; (use-package evil
;;   :straight t
;;   :ensure t
;;   :bind ("C-]" . evil-normal-state)
;;   :init (evil-mode 1)
;;   :config (evil-mode 1)
;;   (setq evil-insert-state-map nil))

;; (use-package evil-leader
;;   :after (evil)
;;   :straight t
;;   :ensure t
;;   :init (evil-leader-mode 1))

(use-package dockerfile-mode
  :straight t)
(use-package yaml-mode
  :straight t)
					; (setq evil-insert-state-map nil)

(use-package web-mode
  :straight t
  :ensure t)
					;  :config (add-hook 'web-mode-hook 'lsp))

(straight-use-package 'typescript-mode)
(straight-use-package 'tide)
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-mode))
(add-hook 'typescript-mode-hook
          #'(()
             (interactive)
             (tide-setup)
             (flycheck-mode +1)
             (tide-hl-identifier-mode +1)
             (company-mode +1)
             (eldoc-mode +1)
             ))
(add-hook 'typescript-ts-mode-hook
          #'(()
             (interactive)
             (tide-setup)
             (flycheck-mode +1)
             (tide-hl-identifier-mode +1)
             (company-mode +1)
             (eldoc-mode +1)
             ))

(setq-default show-trailing-whitespace t)

(use-package magit
  :straight t
  :ensure t
  :bind ("C-c g" . magit-status))

(use-package doom-modeline
  :straight t
  :ensure t
  :init (doom-modeline-mode +1))

(use-package neotree
  :straight t
  :ensure t)
(global-set-key [f8] 'neotree-toggle)


					; (when (memq window-system '(mac ns x))
					;   (exec-path-from-shell-initialize))

(straight-use-package
 '(copilot :type git :host github :repo "zerolfx/copilot.el" :files ("dist" "*.el")))

(defun find-node-executable (f)
  (let ((exec-path (append exec-path (parse-colon-path (getenv "Path")))))
    (executable-find f)))

;; 使用するnode.jsを指定
(setq copilot-node-executable (find-node-executable "node"))
(setopt copilot-max-char-warning-disable t)
;; プログラムモードの場合、copilot-modeを実行
(add-hook 'prog-mode-hook 'copilot-mode)

;; copilot用にキーバインドを設定
(defun my-tab ()
  (interactive)
  (or (copilot-accept-completion)
      (company-indent-or-complete-common nil)))

(global-set-key (kbd "C-TAB") #'my-tab)
(global-set-key (kbd "C-<tab>") #'my-tab)

(with-eval-after-load 'company
  (define-key company-active-map (kbd "C-TAB") #'my-tab)
  (define-key company-active-map (kbd "C-<tab>") #'my-tab)
  (define-key company-mode-map (kbd "C-TAB") #'my-tab)
  (define-key company-mode-map (kbd "C-<tab>") #'my-tab))

;; The `nimsuggest-path' will be set to the value of
;; (executable-find "nimsuggest"), automatically.
(setq nimsuggest-path (find-node-executable "nimsuggest"))

(defun my--init-nim-mode ()
  "Local init function for `nim-mode'."

  ;; Make files in the nimble folder read only by default.
  ;; This can prevent to edit them by accident.
  (when (string-match "/\.nimble/" (or (buffer-file-name) "")) (read-only-mode 1))
  ;; If you want to experiment, you can enable the following modes by
  ;; uncommenting their line.
  (nimsuggest-mode 1)
  (flycheck-mode 1)

  ;; The following modes are disabled for Nim files just for the case
  ;; that they are enabled globally.
  ;; Anything that is based on smie can cause problems.
  (auto-fill-mode 0)
  (electric-indent-local-mode 0))

(add-hook 'nim-mode-hook 'my--init-nim-mode)

(use-package migemo
 :straight (:host github :repo "emacs-jp/migemo" :branch "master" :files ("*.el")))

; (require 'migemo)

(setq org-extend-today-until '4)

(use-package projectile-rails
  :straight t
  :ensure t
  :hook projectile-mode
  :bind-keymap ("C-c r" . projectile-rails-command-map))

(projectile-mode 1)

(use-package company-box
  :straight t
  :ensure t
  :hook company-mode)

(use-package key-chord
  :straight (:host github :repo "zk-phi/key-chord" :branch "master" :files ("key-chord.el"))
  :ensure t
  :init (key-chord-mode +1))

					;(key-chord-define-global ";;" 'evil-normal-state)
					;(key-chord-define-global "jk" 'evil-emacs-state)

(straight-use-package
 '(spaceleader :type git :host github :repo "mohkale/spaceleader"))
(global-flycheck-mode +1)

(use-package fussy
  :straight t
  :ensure t
  :config
  (push 'fussy completion-styles)
  (setq
   ;; For example, project-find-file uses 'project-files which uses
   ;; substring completion by default. Set to nil to make sure it's using
   ;; flx.
   completion-category-defaults nil
   completion-category-overrides nil))

(use-package which-key
  :straight t
  :ensure t
  :init (which-key-mode +1)
  :config (which-key-setup-minibuffer))

(use-package google-translate
  :straight t
  :ensure t
  :bind ("C-c d" . google-translate-smooth-translate)
  :custom
  (google-translate-translation-directions-alist . '(("en" . "ja")
                                                     ("ja" . "en")))
  :config
  (defun google-translate--search-tkk ()
    "Search TKK." (list 430675 2721866130)))
(setq org-feed-alist
      '(("Slashdot"
         "https://rss.slashdot.org/Slashdot/slashdot"
         "~/txt/org/feeds.org" "Slashdot Entries")))

(use-package vundo
  :straight t
  :ensure t
  :bind ("C-c u" . vundo))

(setq view-read-only t)
(defvar pager-keybind
  `( ;; vi-like
    ("h" . backward-word)
    ("l" . forward-word)
    ("j" . next-window-line)
    ("k" . previous-window-line)
    (";" . gene-word)
    ("b" . scroll-down)
    (" " . scroll-up)
    ;; w3m-like
    ("m" . gene-word)
    ("i" . win-delete-current-window-and-squeeze)
    ("w" . forward-word)
    ("e" . backward-word)
    ("(" . point-undo)
    (")" . point-redo)
    ("J" . ,(lambda () (interactive) (scroll-up 1)))
    ("K" . ,(lambda () (interactive) (scroll-down 1)))
    ;; bm-easy
    ("." . bm-toggle)
    ("[" . bm-previous)
    ("]" . bm-next)
    ;; langhelp-like
    ("c" . scroll-other-window-down)
    ("v" . scroll-other-window)
    ))
(defun define-many-keys (keymap key-table &optional includes)
  (let (key cmd)
    (dolist (key-cmd key-table)
      (setq key (car key-cmd)
            cmd (cdr key-cmd))
      (if (or (not includes) (member key includes))
          (define-key keymap key cmd))))
  keymap)

(defun view-mode-hook0 ()
  (define-many-keys view-mode-map pager-keybind)
  (hl-line-mode 1)
  (define-key view-mode-map " " 'scroll-up))
(add-hook 'view-mode-hook 'view-mode-hook0)

;; 書き込み不能なファイルはview-modeで開くように
(defadvice find-file
    (around find-file-switch-to-view-file (file &optional wild) activate)
  (if (and (not (file-writable-p file))
           (not (file-directory-p file)))
      (view-file file)
    ad-do-it))
;; 書き込み不能な場合はview-modeを抜けないように
(defvar view-mode-force-exit nil)
(defmacro do-not-exit-view-mode-unless-writable-advice (f)
  `(defadvice ,f (around do-not-exit-view-mode-unless-writable activate)
     (if (and (buffer-file-name)
	      (not view-mode-force-exit)
	      (not (file-writable-p (buffer-file-name))))
         (message "File is unwritable, so stay in view-mode.")
       ad-do-it)))

(do-not-exit-view-mode-unless-writable-advice view-mode-exit)
(do-not-exit-view-mode-unless-writable-advice view-mode-disable)

(setq plstore-cache-passphrase-for-symmetric-encryption t)
;; Google Calendar認証情報は環境変数またはauth-sourceから取得
;; 環境変数を設定:
;;   export GCAL_CLIENT_ID="your-client-id"
;;   export GCAL_CLIENT_SECRET="your-client-secret"
;; または ~/.authinfo.gpg に:
;;   machine gcal-client-id login user password your-client-id
;;   machine gcal-client-secret login user password your-client-secret
(setq org-gcal-client-id
      (or (getenv "GCAL_CLIENT_ID")
          (auth-source-pick-first-password :host "gcal-client-id"))
      org-gcal-client-secret
      (or (getenv "GCAL_CLIENT_SECRET")
          (auth-source-pick-first-password :host "gcal-client-secret"))
      org-gcal-file-alist '(("lacrimalelacrimal@gmail.com" .  "~/.emacs.d/org-gcal/your-calendar.org")))

(use-package rg
  :straight t
  :ensure t)

(use-package org-gcal
  :straight t
  :ensure t)

;; (defconst my-system-is-wsl2
;;   (eval-when-compile
;;     (getenv "WSL_DISTRO_NAME")))

;; (defconst my-system-is-wsl2
;;   (eval-when-compile
;;     (getenv "WSL_DISTRO_NAME")))

;; (defconst my-system-is-wsl2
;;   (eval-when-compile
;;     (getenv "WSL_DISTRO_NAME")))

;; (let ((cmd-exe "/mnt/c/Windows/System32/cmd.exe")
;;       (cmd-args '("/c" "start")))
;;   (when (file-exists-p cmd-exe)
;;     (setq browse-url-generic-program  cmd-exe
;; 	  browse-url-generic-args     cmd-args
;; 	              browse-url-browser-function 'browse-url-generic)))


(setq chatgpt-shell-openai-key (getenv "OPENAI_API_KEY"))

(defconst my-system-is-wsl2
  (eval-when-compile
    (getenv "WSL_DISTRO_NAME")))

(defun my-browse-url-wsl-host-browser (url &rest _args)
  "Browse URL with WSL host web browser."
  (prog1 (message "Open %s" url)
    (shell-command-to-string
     (mapconcat #'shell-quote-argument
                (list "cmd.exe" "/c" "start" url) " "))))

(when (eval-when-compile my-system-is-wsl2)
  (setopt browse-url-browser-function #'my-browse-url-wsl-host-browser))

;(setq browse-url-browser-function 'eww-browse-url)
;(setq browse-url-browser-function 'vivaldi)
(setq browse-url-browser-function 'browse-url-default-windows-browser)


(defun open-work-directory ()
  "Open the Work directory."
  (interactive)
  (dired "~/Documents/Repository/Works"))

(defun open-game-directory ()
  "Open the Work directory."
  (interactive)
  (dired "~/WeaponMakingGame"))

(setq projectile-globally-ignored-directories
      (append '("vendor") projectile-globally-ignored-directories))


(global-set-key (kbd "C-c w w") 'open-work-directory)
(global-set-key (kbd "C-c w g") 'open-game-directory)

;; (defun my/org-combine-weekly-journals ()
;;   "Combine the past week's journal files from Sunday to Saturday into a single buffer."
;;   (interactive)
;;   (let ((journal-dir "~/Dropbox/Org/journal/")
;;         (output-buffer (get-buffer-create "*Weekly Journal*"))
;;         (current-date (current-time))
;;         (one-day (* 24 60 60))
;;         (date-format "%Y%m%d"))
;;     ;; Calculate the start of the week (Sunday)
;;     (let* ((current-day-of-week (string-to-number (format-time-string "%u" current-date)))
;;            (days-since-sunday (mod (+ current-day-of-week 6) 7))
;;            (start-of-week (time-subtract current-date (seconds-to-time (* days-since-sunday one-day)))))
;;       (with-current-buffer output-buffer
;;         (erase-buffer)
;;         ;; Loop through each day of the week from Sunday to Saturday
;;         (dotimes (i 7)
;;           (let* ((date (time-add start-of-week (seconds-to-time (* i one-day))))
;;                  (date-str (format-time-string date-format date))
;;                  (file (expand-file-name date-str journal-dir)))
;;             (when (file-exists-p file)
;;               (insert (format "### %s ###\n\n" date-str))  ;; ファイルのセクションを追加
;;               (insert-file-contents file)
;;               (goto-char (point-max))
;;               (insert "\n\n"))))
;;         (org-mode)
;; 	(view-mode 1))
;;       (switch-to-buffer output-buffer))))

;; (global-set-key (kbd "C-c i") 'my/org-combine-weekly-journals)
(set-frame-font "Iosevka NFM ExtraLight-16" nil t)
(set-fontset-font t 'unicode "Iosevka NFM ExtraLight-16" nil 'prepend)

(defvar my/org-weekly-journal-date (current-time)
  "現在表示している週の開始日を保持する変数。")

(defun my/org-combine-weekly-journals (&optional date)
  "指定されたDATE（または現在の日付）を含む週のジャーナルファイルを一つのバッファにまとめます。"
  (interactive)
  (let ((journal-dir "~/Dropbox/Org/journal/")
        (output-buffer (get-buffer-create "*Weekly Journal*"))
        (one-day (* 24 60 60))
        (date-format "%Y%m%d")
        (display-format "%Y-%m-%d")
        (current-date (or date (current-time))))
    ;; 週の開始日（日曜日）を計算
    (let* ((current-day-of-week (string-to-number (format-time-string "%u" current-date)))
           (days-since-sunday (mod (+ current-day-of-week 6) 7))
           (start-of-week (time-subtract current-date (seconds-to-time (* days-since-sunday one-day))))
           (end-of-week (time-add start-of-week (seconds-to-time (* 6 one-day))))
           (start-of-week-str (format-time-string display-format start-of-week))
           (end-of-week-str (format-time-string display-format end-of-week)))
      ;; 現在の週の開始日を保持
      (setq my/org-weekly-journal-date start-of-week)
      (with-current-buffer output-buffer
        (let ((inhibit-read-only t))  ;; view-modeの影響を防ぐ
          (erase-buffer)
          ;; 日付範囲を最初に挿入
          (insert (format "#+TITLE: Weekly Journal: %s - %s\n\n" start-of-week-str end-of-week-str))
          ;; 日曜日から土曜日まで各日をループ
          (dotimes (i 7)
            (let* ((date (time-add start-of-week (seconds-to-time (* i one-day))))
                   (date-str (format-time-string date-format date))
                   (file (expand-file-name date-str journal-dir)))
	      (when (file-exists-p file)
                (insert (format "* %s\n\n" (format-time-string display-format date)))  ;; Orgの見出しを使用
                (insert-file-contents file)
                (goto-char (point-max))
                (insert "\n\n"))))
          (org-mode)
          ;; ナビゲーションのためのローカルキーバインドを定義
          (local-set-key (kbd "C-c i n") 'my/org-weekly-journal-next-week)
          (local-set-key (kbd "C-c i p") 'my/org-weekly-journal-previous-week)
          (view-mode 1)))  ;; view-modeを有効化
      (switch-to-buffer output-buffer))))

(defun my/org-weekly-journal-next-week ()
  "次の週のジャーナルを表示します。"
  (interactive)
  (let ((next-week-date (time-add my/org-weekly-journal-date (seconds-to-time (* 7 24 60 60)))))
    (my/org-combine-weekly-journals next-week-date)))

(defun my/org-weekly-journal-previous-week ()
  "前の週のジャーナルを表示します。"
  (interactive)
  (let ((previous-week-date (time-subtract my/org-weekly-journal-date (seconds-to-time (* 7 24 60 60)))))
    (my/org-combine-weekly-journals previous-week-date)))

(global-set-key (kbd "C-c i") 'my/org-combine-weekly-journals)



(defun close-other-frames-and-buffers ()
  "Close all other frames and buffers, then open the dashboard."
  (interactive)
  ;; Close all other frames
  (dolist (frame (frame-list))
    (unless (eq frame (selected-frame))
      (delete-frame frame)))
  ;; Open dashboard
  (dashboard-refresh-buffer)
  ;; Close all other buffers
  (mapc 'kill-buffer (delq (current-buffer) (buffer-list)))
  ;; Ensure the dashboard buffer is displayed
  (switch-to-buffer "*dashboard*"))

;; キーバインドを設定
(global-set-key (kbd "C-c d") 'close-other-frames-and-buffers)

(use-package darkroom
  :straight t
  :ensure t)

(use-package ddskk
  :straight (ddskk :host github :repo "skk-dev/ddskk")
  :bind (("C-\\" . skk-mode))
  :init
  (setq skk-user-directory "~/.emacs.d/ddskk")
  (setq skk-init-file "~/.emacs.d/ddskk/init")
  (setq skk-byte-compile-init-file t)
  (setq skk-large-jisyo "~/.emacs.d/skk-get-jisyo/SKK-JISYO.myjisyo"))

(use-package ddskk-posframe
  :straight t
  :ensure t
  :init (skk-posframe-mode 1))

(setq x-select-enable-clipboard t)

(defun wsl-paste ()
  (interactive)
  (insert (shell-command-to-string "powershell.exe -command 'Get-Clipboard'")))

(global-set-key (kbd "C-c C-v") 'wsl-paste)

(use-package hydra
  :straight t
  :ensure t)

(use-package gdscript-mode
  :straight t
  :ensure t
;  :hook (gdscript-mode .eglot-ensure)
  :config ((add-to-list 'auto-mode-alist '("\\.gd\\'" . gdscript-mode))
						   (gdscript-eglot-version 4)))


(use-package consult
  :ensure t
  :straight t
  :bind (("C-c h" . consult-history)
	 ("C-c m" . consult-mode-command)
	 ; ("C-c b" . consult-bookmark)
	 ("C-c k" . consult-kmacro)
	 ("C-x M-:" . consult-complex-command)
	 ("C-x b" . consult-buffer)
	 ("C-x 4 b" . consult-buffer-other-window)
	 ("C-x 5 b" . consult-buffer-other-frame)
	 ("M-#" . consult-register-load)
	 ("M-'" . consult-register-store)
	 ("C-M-#" . consult-register)
	 ("M-y" . consult-yank-pop)
	 ("M-g e" . consult-compile-error)
	 ("M-g f" . consult-flymake)
	 ("M-g g" . consult-goto-line)
	 ("M-g M-g" . consult-goto-line)
	 ("M-g o" . consult-outline)
	 ("M-g m" . consult-mark)
	 ("M-g k" . consult-global-mark)
	 ("M-g i" . consult-imenu)
	 ("M-g I" . consult-imenu-multi)
	 ("M-s f" . consult-find)
	 ("M-s F" . consult-locate)
	 ("M-s g" . consult-grep)
	 ("M-s G" . consult-git-grep)
	 ("M-s r" . consult-ripgrep)
	 ("M-s l" . consult-line)
	 ("M-s L" . consult-line-multi)
	 ("M-s m" . consult-multi-occur)
	 ("M-s k" . consult-keep-lines)
	 ("M-s u" . consult-focus-lines)
	 ("M-s e" . consult-isearch)))

(server-start)
(require 'whitespace)
(setq whitespace-style '(face tabs))
(global-whitespace-mode 1)

(cond
 ((eq system-type 'darwin) ; macOS
  (setq treesit-extra-load-path '("/Users/im_tan/tree-sitter-gdscript/src")))
 ((eq system-type 'windows-nt) ; Windows
  (setq treesit-extra-load-path '("~/tree-sitter-gdscript/src"))))

(setq org-startup-indented nil)

(setq gdscript-use-tab-indents t) ;; タブでインデント（デフォルト：t）
(setq gdscript-indent-offset 4) ;; タブ幅を4に設定
(setq gdscript-godot-executable
      (if (eq system-type 'windows-nt)
          "C:/Users/lacri/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64.exe"
        "/Applications/Godot.app/Contents/MacOS/Godot"))
(setq gdscript-gdformat-save-and-format t) ;; 保存時にgdformatでフォーマット

(use-package tree-sitter
  :straight t
  :ensure t
  :config
  (global-tree-sitter-mode)
  (add-hook 'tree-sitter-after-on-hook #'tree-sitter-hl-mode))

(use-package hydra-posframe
  :straight (hydra-posframe :host github :repo "Ladicle/hydra-posframe")
  :ensure t
  :hook (after-init . hydra-posframe-mode))

(use-package blamer
  :straight t
  :ensure t)
(global-set-key (kbd "C-c <left>")  'windmove-left)
(global-set-key (kbd "C-c <down>")  'windmove-down)
(global-set-key (kbd "C-c <up>")    'windmove-up)
(global-set-key (kbd "C-c <right>") 'windmove-right)

(defun my/use-bundler-for-rubocop ()
  (when (locate-dominating-file default-directory "Gemfile")
    (setq-local flycheck-command-wrapper-function
                (lambda (command) (append '("bundle" "exec") command)))
    (setq-local flycheck-ruby-rubocop-executable "bundle exec rubocop")))

(add-hook 'ruby-mode-hook #'my/use-bundler-for-rubocop)

(use-package rubocop
  :straight t
  :ensure t)

(defun my-org-mode-visual-fill ()
  "Enablevisual-fill-column-mode only in Org mode."
  (visual-fill-column-mode 1))

(add-hook 'org-mode-hook #'my-org-mode-visual-fill)

(use-package helm-wikipedia
  :straight t
  :ensure t)

(use-package autorevert
  :straight t
  :ensure t)


(use-package wikipedia-mode
  :straight t
  :ensure t)

(use-package consult-spotify
  :straight t
  :ensure t)

(use-package nyan-mode
  :straight t
  :ensure t
  :config
  (nyan-mode 1)
  (nyan-start-animation))

(setq dashboard-items '((recents  . 5)
                        (bookmarks . 5)
                        (projects . 5)
                        (agenda . 5)
                        (registers . 5)))
(setq elfeed-feeds
      '("http://nullprogram.com/feed/"
        "https://planet.emacslife.com/atom.xml"))

(defun my-enable-skk-mode ()
  "新しいバッファで自動的にSKKモードを有効にし、ローマ字入力モードにする。"
  (skk-mode 1)
  (skk-latin-mode 1))

(add-hook 'find-file-hook 'my-enable-skk-mode)
(add-hook 'after-change-major-mode-hook 'my-enable-skk-mode)

;;; *.~ とかのバックアップファイルを作らない
(setq make-backup-files nil)
;;; .#* とかのバックアップファイルを作らない
(setq auto-save-default nil)

(use-package org-modern
  :straight t
  :ensure t
  :custom
  (org-modern-hide-stars nil)		; adds extra indentation
  (org-modern-table nil)
  (org-modern-list
   '(;; (?- . "-")
     (?* . " ")
     (?+ . "‣")))
  (org-modern-block-name '("" . "")) ; or other chars; so top bracket is drawn promptly
  :hook
  (org-mode . org-modern-mode)
  (org-agenda-finalize . org-modern-agenda))
;; (setq org-modern-star nil) ; 見出しの装飾を無効化
;; Minimal UI
(package-initialize)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

;; Choose some fonts
;; (set-face-attribute 'default nil :family "Iosevka")
;; (set-face-attribute 'variable-pitch nil :family "Iosevka Aile")
;; (set-face-attribute 'org-modern-symbol nil :family "Iosevka")

;; Add frame borders and window dividers
(dolist (face '(window-divider
                window-divider-first-pixel
                window-divider-last-pixel))
  (face-spec-reset-face face)
  (set-face-foreground face (face-attribute 'default :background)))
(set-face-background 'fringe (face-attribute 'default :background))

(setq
 ;; Edit settings
 org-auto-align-tags nil
 org-tags-column 0
 org-catch-invisible-edits 'show-and-error
 org-special-ctrl-a/e t
 org-insert-heading-respect-content t

 ;; Org styling, hide markup etc.
 org-hide-emphasis-markers t
 org-pretty-entities t

 ;; Agenda styling
 org-agenda-tags-column 0
 org-agenda-block-separator ?-
 org-agenda-time-grid
 '((daily today require-timed)
   (800 1000 1200 1400 1600 1800 2000 2200 2400)
   " ┄┄┄┄┄ " "┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄")
 org-agenda-current-time-string
 "◀── now ─────────────────────────────────────────────────")

;; Ellipsis styling
(setq org-ellipsis "…")
(set-face-attribute 'org-ellipsis nil :inherit 'default :box nil)

(global-org-modern-mode)

(use-package org-modern-indent
  :straight (org-modern-indent :type git :host github :repo "jdtsmith/org-modern-indent")
  :ensure t
   :config ; add late to hook
  (add-hook 'org-mode-hook #'org-modern-indent-mode 90))

(use-package org-bullets
  :straight t
  :ensure t
  :config (setq org-bullets-bullet-list '("" "" "" "" "" "" "" "" "" ""))
  :hook (org-mode . org-bullets-mode))

(message "%s" (frame-parameter nil 'font))

;(straight-use-package 'smartparens)
;(setq org-modernstar '("➤" "➥" "➩" "➪" "➫" "➬" "➭" "➮"))
;(setq org-modern-replace-stars  "◉○◈◇✳")
(with-eval-after-load 'smartparens
  (require 'smartparens-config)

  (defun indent-between-pair (&rest _ignored)
    (newline)
    (indent-according-to-mode)
    (forward-line -1)
    (indent-according-to-mode))

  (sp-local-pair 'prog-mode "{" nil :post-handlers '((indent-between-pair "RET")))
  (sp-local-pair 'prog-mode "[" nil :post-handlers '((indent-between-pair "RET")))
  (sp-local-pair 'prog-mode "(" nil :post-handlers '((indent-between-pair "RET"))))

;; (smartparens-global-mode +1)
(use-package olivetti
  :straight t
  :ensure t
  :hook ((org-mode . olivetti-mode)
	 (org-agenda-mode . olivetti-mode)
	 (markdown-mode . olivetti-mode))
  :config
  (setq olivetti-body-width 0.7))

(use-package org-super-agenda
  :straight t
  :ensure t
  :config
  (org-super-agenda-mode))

(add-hook 'org-mode-hook (lambda () (display-line-numbers-mode -1)))
(add-hook 'org-agenda-mode-hook (lambda () (display-line-numbers-mode -1)))



;(set-face-attribute 'fixed-pitch nil :family "Hack" :height 1.0) ; or whatever font family

;(custom-set-faces
; '(default ((t (:family "iosevka nfm")))))

(use-package gptel
  :config
  (setq gptel-api-key (auth-source-pick-first-password :host "openai.com"))
  (setq gptel-default-mode 'org-mode)
  (setq gptel-model "gpt-3.5-turbo"))

(setq org-todo-keywords
      (quote ((sequence "TODO(t)" "DOING(g)" "|" "DONE(d)"))))

;; This assumes you've installed the package via MELPA.
(use-package ligature
  :straight t
  :config
  ;; Enable the "www" ligature in every possible major mode
  (ligature-set-ligatures 't '("www"))
  ;; Enable traditional ligature support in eww-mode, if the
  ;; `variable-pitch' face supports it
  (ligature-set-ligatures 'eww-mode '("ff" "fi" "ffi"))
  ;; Enable all Cascadia Code ligatures in programming modes
  (ligature-set-ligatures 'prog-mode '("|||>" "<|||" "<==>" "<!--" "####" "~~>" "***" "||=" "||>"
                                       ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "=/=" "!=="
                                       "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
                                       "<~~" "<~>" "<*>" "<||" "<|>" "<$>" "<==" "<=>" "<=<" "<->"
                                       "<--" "<-<" "<<=" "<<-" "<<<" "<+>" "</>" "###" "#_(" "..<"
                                       "..." "+++" "/==" "///" "_|_" "www" "&&" "^=" "~~" "~@" "~="
                                       "~>" "~-" "**" "*>" "*/" "||" "|}" "|]" "|=" "|>" "|-" "{|"
                                       "[|" "]#" "::" ":=" ":>" ":<" "$>" "==" "=>" "!=" "!!" ">:"
                                       ">=" ">>" ">-" "-~" "-|" "->" "--" "-<" "<~" "<*" "<|" "<:"
                                       "<$" "<=" "<>" "<-" "<<" "<+" "</" "#{" "#[" "#:" "#=" "#!"
                                       "##" "#(" "#?" "#_" "%%" ".=" ".-" ".." ".?" "+>" "++" "?:"
                                       "?=" "?." "??" ";;" "/*" "/=" "/>" "//" "__" "~~" "(*" "*)"
                                       "\\\\" "://"))
    (ligature-set-ligatures 'org-mode '("|||>" "<|||" "<==>" "<!--" "####" "~~>" "***" "||=" "||>"
                                       ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "=/=" "!=="
                                       "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
                                       "<~~" "<~>" "<*>" "<||" "<|>" "<$>" "<==" "<=>" "<=<" "<->"
                                       "<--" "<-<" "<<=" "<<-" "<<<" "<+>" "</>" "###" "#_(" "..<"
                                       "..." "+++" "/==" "///" "_|_" "www" "&&" "^=" "~~" "~@" "~="
                                       "~>" "~-" "**" "*>" "*/" "||" "|}" "|]" "|=" "|>" "|-" "{|"
                                       "[|" "]#" "::" ":=" ":>" ":<" "$>" "==" "=>" "!=" "!!" ">:"
                                       ">=" ">>" ">-" "-~" "-|" "->" "--" "-<" "<~" "<*" "<|" "<:"
                                       "<$" "<=" "<>" "<-" "<<" "<+" "</" "#{" "#[" "#:" "#=" "#!"
                                       "##" "#(" "#?" "#_" "%%" ".=" ".-" ".." ".?" "+>" "++" "?:"
                                       "?=" "?." "??" ";;" "/*" "/=" "/>" "//" "__" "~~" "(*" "*)"
                                       "\\\\" "://"))
  ;; Enables ligature checks globally in all buffers. You can also do it
  ;; per mode with `ligature-mode'.
  (global-ligature-mode t))

;(setq gc-cons-threshold (* 1000 1024 1024)) ;; 100MB
;(setq garbage-collection-messages t)
;(setq gc-cons-percentage 0.1)

(use-package pulsar
  :straight t
  :ensure t
  :config
  (pulsar-global-mode +1))

(use-package lin
  :straight t
  :init
  (setq lin-face 'lin-red)
  (lin-global-mode +1))

(use-package go-translate
  :straight t
  :init
  (setq gts-translate-list '(("en" "ja")))
  :config
  (with-eval-after-load 'meow
    (meow-leader-define-key
     '("T" . gts-do-translate))))

(use-package treesit-auto
  :straight t
  :config
  (setq treesit-auto-install 'prompt)
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode +1))

(use-package string-inflection
  :straight t
  :bind ( :map my-string-inflection-map
          ("a" . string-inflection-all-cycle)
          ("_" . string-inflection-underscore)
          ("p" . string-inflection-pascal-case)
          ("c" . string-inflection-camelcase)
          ("u" . string-inflection-upcase)
          ("k" . string-inflection-kebab-case)
          ("C" . string-inflection-capital-underscore))
  :init
  (defvar my-string-inflection-map (make-keymap))
  (with-eval-after-load 'meow
    (meow-leader-define-key
     `("i" . ("inflection" . ,my-string-inflection-map)))))

(use-package vertico-truncate
  :straight t
  :vc ( :fetcher github :repo "jdtsmith/vertico-truncate")
  :config
  (vertico-truncate-mode +1))

(use-package all-the-icons
  :straight t
  :if (display-graphic-p))


(use-package dired-subtree
  :straight t
  :config
  (advice-add 'dired-subtree-toggle :after (lambda ()
                                             (interactive)
                                             (when all-the-icons-dired-mode
                                               (revert-buffer)))))

(set-fontset-font t 'unicode (font-spec :family "github-octicons") nil 'append)

(use-package nerd-icons-dired
  :straight t
  :hook
  (dired-mode . nerd-icons-dired-mode))
(add-to-list 'org-modules 'org-habit t)
(setq org-treat-insert-todo-heading-as--state-change t)
(setq org-log-into-drawer t)
(setq org-habit-show-habits-only-for-today nil)
(use-package org-roam-bibtex
  :straight t
  :after org-roam
  :config
  (require 'org-ref))
(setq org-agenda-prefix-format
      '((agenda . " %i %-12:c%?-12t %s")  ;; agenda view
        (todo . " %i %-12:c")            ;; todo view
        (tags . " %i %-12:c")            ;; tags view
        (search . " %i %-12:c")))        ;; search view


(defun my/org-roam-insert-with-page ()
  "Insert an Org-roam link with an optional page number."
  (interactive)
  (let* ((node (org-roam-node-read))
         (link (org-roam-node-formatted node))
         (id (org-roam-node-id node))
         (page (read-string "Enter page number (e.g., P.56): ")))
    (insert (format "[[id:%s][%s]] %s" id link page))))

;; (setq org-roam-capture-templates
;;       '(("b" "Book Notes" plain
;;          "%?"
;;          :target (file+head "books/${slug}.org"
;;                             "#+title: ${title}\n#+date: %<%Y-%m-%d>\n#+filetags: :本:\n")
;;          :unnarrowed t)))

(global-set-key (kbd "C-c n p") 'my/org-roam-insert-with-page)

(use-package org-roam-books
  :load-path "~/.emacs.d/lisp" ;; org-roam-books.elを保存したディレクトリ
  :after org-roam
  :config
  (org-roam-books-setup))

(use-package copilot-chat
  :straight (:host github :repo "chep/copilot-chat.el" :files ("*.el"))
  :after (request org markdown-mode))
(provide 'init)
;;; init.el ends here
