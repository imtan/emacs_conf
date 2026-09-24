;;; imepad.el --- Use Emacs as an input pad for other apps -*- lexical-binding: t; -*-

;; Author: Imtan
;; Version: 0.1
;; Package-Requires: ((emacs "28.1"))
;; Keywords: i18n, convenience

;;; Commentary:

;; imepad の Emacs 版。どのアプリで文字を書くときも、Emacs を小窓として開いて
;; 書き、確定すると元のアプリに貼り付ける。
;;
;; 仕組み（$EDITOR として emacsclient を使うのと同じ）:
;;   1. OS 側の起動スクリプト (imepad.sh / imepad.ahk) がショートカットで呼ばれ、
;;      今アクティブなウィンドウを覚えて空の一時ファイル imepad-XXXX.txt を作る
;;   2. emacsclient -c -F '((name . "imepad") ...)' <一時ファイル> で小窓を開き、
;;      emacsclient が戻るまで待つ
;;   3. ここで書いて C-c C-c → 本文をファイルに書いてフレームが閉じる
;;      C-c C-k → 空のまま閉じる（何も貼らない）
;;   4. 起動スクリプトが中身をクリップボードに入れ、元のウィンドウに戻して貼り付ける
;;
;; 設定例 (init.el):
;;   (add-to-list 'load-path "~/path/to/imepad")
;;   (require 'imepad)
;;   (imepad-setup)
;;   ;; ddskk で書きたいなら:
;;   ;; (setq imepad-input-method "japanese-skk")
;;   ;; org で書きたいなら:
;;   ;; (setq imepad-major-mode #'org-mode)

;;; Code:

(require 'server)

(defgroup imepad nil
  "Use Emacs as an input pad for other applications."
  :group 'convenience
  :prefix "imepad-")

(defcustom imepad-file-regexp "/imepad-[^/]*\\.txt\\'"
  "Regexp matching the temporary files the launcher hands to emacsclient."
  :type 'regexp)

(defcustom imepad-major-mode #'text-mode
  "Major mode for the pad buffer."
  :type 'function)

(defcustom imepad-input-method nil
  "Emacs input method to turn on in the pad, e.g. \"japanese-skk\".
nil leaves Emacs input methods alone (use the OS IME instead)."
  :type '(choice (const :tag "None" nil) string))

(defcustom imepad-activate-os-ime t
  "Non-nil means turn the OS IME on when the pad opens.
Windows: `w32-set-ime-open-status'.  Linux: fcitx5-remote -o.
macOS: switch to `imepad-macos-input-source' (needs that set).
Ignored when `imepad-input-method' is set, so the OS IME and an
Emacs input method never convert the same keys twice."
  :type 'boolean)

(defcustom imepad-macos-input-source nil
  "macOS input source ID to switch to when the pad opens.
For example \"com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese\".
Uses `mac-select-input-source' (emacs-mac port) when available,
otherwise the external `macism' command."
  :type '(choice (const :tag "Don't switch" nil) string))

(defcustom imepad-strip-trailing-newlines t
  "Non-nil means drop trailing newlines before sending."
  :type 'boolean)

(defcustom imepad-save-to-kill-ring t
  "Non-nil means also push each sent text onto the kill ring (history)."
  :type 'boolean)

(defcustom imepad-ret-sends nil
  "Non-nil means RET sends, like a chat box.  Use C-j for a newline."
  :type 'boolean)

(defcustom imepad-focus-delay 0.05
  "Seconds to wait after the pad frame appears before focusing it."
  :type 'number)

(defcustom imepad-setup-hook nil
  "Hook run in the pad buffer once its frame has focus."
  :type 'hook)

(defvar imepad-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'imepad-send)
    (define-key map (kbd "C-c C-k") #'imepad-cancel)
    (define-key map (kbd "RET") #'imepad-return)
    map)
  "Keymap for `imepad-mode'.")

;;;###autoload
(define-minor-mode imepad-mode
  "Minor mode for the imepad buffer.

\\{imepad-mode-map}"
  :lighter " Pad"
  :keymap imepad-mode-map
  (when imepad-mode
    (setq-local require-final-newline nil)
    (setq-local backup-inhibited t)
    (setq-local buffer-file-coding-system 'utf-8-unix)
    (setq-local server-client-instructions nil)
    (auto-save-mode -1)
    (setq header-line-format
          (substitute-command-keys
           (concat "\\<imepad-mode-map>\\[imepad-send] 送る   "
                   "\\[imepad-cancel] 破棄"
                   (if imepad-ret-sends "   RET 送る / C-j 改行" ""))))))

(defun imepad--check ()
  "Signal an error unless the current buffer is a pad."
  (unless imepad-mode
    (user-error "Not an imepad buffer")))

(defun imepad--settle-input-method ()
  "Confirm a conversion the Emacs input method still has pending.
Closing the pad while SKK is mid-conversion (▽/▼) aborts the server's
cleanup: the buffer is left behind with SKK's markers dangling.
Confirming first also keeps the ▽/▼ marker out of the sent text."
  (when (and (bound-and-true-p skk-henkan-mode) (fboundp 'skk-kakutei))
    (skk-kakutei)))

(defun imepad--finish (text)
  "Write TEXT to the pad file and hand control back to the launcher."
  (let ((coding-system-for-write 'utf-8-unix))
    (write-region text nil buffer-file-name nil 'silent))
  (set-buffer-modified-p nil)
  ;; Marks the buffer done: the server kills it, deletes the pad frame
  ;; and lets the waiting emacsclient exit.
  (server-edit))

(defun imepad-send ()
  "Send the pad's text to the app it was opened from."
  (interactive)
  (imepad--check)
  (imepad--settle-input-method)
  (let ((text (buffer-substring-no-properties (point-min) (point-max))))
    (when imepad-strip-trailing-newlines
      (setq text (replace-regexp-in-string "[\r\n]+\\'" "" text)))
    (when (and imepad-save-to-kill-ring (not (string-empty-p text)))
      (kill-new text))
    (imepad--finish text)))

(defun imepad-cancel ()
  "Close the pad without sending anything."
  (interactive)
  (imepad--check)
  (imepad--settle-input-method)
  (imepad--finish ""))

(defun imepad-return ()
  "Send when `imepad-ret-sends' is non-nil, otherwise run RET's usual command.
With `imepad-ret-sends', RET during an SKK conversion (▽/▼) only
confirms it, like a chat box with an IME: RET to confirm, RET again
to send."
  (interactive)
  (cond
   ((not imepad-ret-sends)
    (let ((cmd (let ((imepad-mode nil))
                 (key-binding (kbd "RET") t))))
      (when (commandp cmd)
        (setq this-command cmd)
        (call-interactively cmd))))
   ((and (bound-and-true-p skk-henkan-mode) (fboundp 'skk-kakutei))
    (skk-kakutei))
   (t (imepad-send))))

;;; OS IME

(defun imepad--os-ime-on ()
  "Turn the OS input method on for the pad, where we know how."
  (pcase system-type
    ('windows-nt
     (when (fboundp 'w32-set-ime-open-status)
       (w32-set-ime-open-status t)))
    ('darwin
     (when imepad-macos-input-source
       (cond ((fboundp 'mac-select-input-source)
              (mac-select-input-source imepad-macos-input-source))
             ((executable-find "macism")
              (call-process "macism" nil 0 nil imepad-macos-input-source)))))
    (_
     (cond ((executable-find "fcitx5-remote")
            (call-process "fcitx5-remote" nil 0 nil "-o"))
           ((executable-find "fcitx-remote")
            (call-process "fcitx-remote" nil 0 nil "-o"))))))

;;; Server hooks

(defun imepad--on-visit ()
  "Turn a visited pad file into a pad buffer (for `server-visit-hook')."
  (when (and buffer-file-name
             (string-match-p imepad-file-regexp buffer-file-name))
    (funcall imepad-major-mode)
    (imepad-mode 1)))

(defun imepad--after-display (buffer)
  "Focus BUFFER's pad frame and switch the IME on."
  (when (buffer-live-p buffer)
    (when-let* ((win (get-buffer-window buffer t)))
      (select-frame-set-input-focus (window-frame win))
      (with-current-buffer buffer
        (when (and imepad-activate-os-ime (not imepad-input-method))
          (imepad--os-ime-on))
        (run-hooks 'imepad-setup-hook)))))

(defun imepad--on-switch ()
  "Prepare the pad once it is shown (for `server-switch-hook')."
  (when imepad-mode
    (when imepad-input-method
      (activate-input-method imepad-input-method))
    ;; The server makes the new frame visible only after this hook,
    ;; so focus it a moment later.
    (run-at-time imepad-focus-delay nil
                 #'imepad--after-display (current-buffer))))

(defun imepad--on-delete-frame (frame)
  "If FRAME is closed from the window manager, discard the pad cleanly."
  (dolist (win (window-list frame 'no-minibuf))
    (with-current-buffer (window-buffer win)
      (when imepad-mode
        (imepad--settle-input-method)
        ;; Unmodified, so the server kills the buffer with its client.
        (set-buffer-modified-p nil)))))

;;;###autoload
(defun imepad-setup ()
  "Install the hooks imepad needs and make sure the server runs."
  (interactive)
  (add-hook 'server-visit-hook #'imepad--on-visit)
  (add-hook 'server-switch-hook #'imepad--on-switch)
  ;; Run before `server-handle-delete-frame'.
  (add-hook 'delete-frame-functions #'imepad--on-delete-frame -90)
  (with-eval-after-load 'recentf
    (defvar recentf-exclude)
    (add-to-list 'recentf-exclude imepad-file-regexp))
  (unless (or (daemonp) server-process)
    (server-start)))

(provide 'imepad)
;;; imepad.el ends here
