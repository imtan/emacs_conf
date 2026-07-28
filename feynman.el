;;; feynman.el --- Feynman学習システムのEmacs面 -*- lexical-binding: t; -*-

;; 位置づけ:
;;   Feynman学習システムのEmacs面（復習期日・候補の供給層 +
;;   Claude Codeセッションの起動口）。feynman.org への書き込みは
;;   Claude Code側のfeynmanスキルの責務であり、このファイルは読み取り専用で扱う。

;;; Code:

(require 'org)
(require 'cl-lib)
(require 'subr-x)

(defvar skilltree-trees)
(defvar eat-terminal)
(declare-function skilltree--scan "skilltree-menu")
(declare-function skilltree--ready-status "skilltree-menu")
(declare-function vterm "vterm" (&optional buffer-name))
(declare-function vterm-send-string "vterm" (string &optional paste-p))
(declare-function vterm-send-return "vterm" ())
(declare-function eat "eat" (&optional arg))
(declare-function eat-term-send-string "eat" (terminal string))

(defgroup feynman nil
  "Feynman学習システムのEmacsインターフェース。"
  :group 'org
  :prefix "feynman-")

(defcustom feynman-learning-directory
  (expand-file-name "Org/learning"
                    (or (getenv "LEARNING_DROPBOX") "~/Dropbox"))
  "Feynmanセッションログが置かれているディレクトリ。"
  :type 'directory
  :group 'feynman)

(defcustom feynman-claude-directory
  (expand-file-name "Org"
                    (or (getenv "LEARNING_DROPBOX") "~/Dropbox"))
  "Feynman用Claude Codeセッションを起動するディレクトリ。"
  :type 'directory
  :group 'feynman)

(defcustom feynman-frontier-limit 5
  "新規候補として表示するREADYノードの最大件数。"
  :type 'integer
  :group 'feynman)

(defcustom feynman-claude-startup-delay 4.0
  "claude起動からスラッシュコマンド送信まで待つ秒数。"
  :type 'number
  :group 'feynman)

(defconst feynman--buffer-name "*Feynman Menu*")
(defconst feynman--terminal-buffer-name "*feynman: claude*")

(defvar-local feynman--terminal-type nil)

(defun feynman--file ()
  "feynman.orgの絶対パスを返す。"
  (expand-file-name "feynman.org" feynman-learning-directory))

(defun feynman--scheduled ()
  "現在の見出しのSCHEDULEDタイムスタンプを返す。"
  (or (org-entry-get (point) "SCHEDULED")
      ;; データ契約どおりプロパティドロワー後にある場合も扱う。
      (save-excursion
        (let ((end (save-excursion
                     (outline-next-heading)
                     (point))))
          (when (re-search-forward
                 "^SCHEDULED:[ \t]*\\(<[^>\n]+>\\)" end t)
            (match-string-no-properties 1))))))

(defun feynman--entries ()
  "feynman.orgから各トピックの最新エントリを返す。"
  (let ((file (feynman--file))
        (latest (make-hash-table :test #'equal)))
    (when (file-exists-p file)
      (with-current-buffer (find-file-noselect file)
        (org-with-wide-buffer
         (goto-char (point-min))
         (while (re-search-forward org-heading-regexp nil t)
           (let ((heading (org-get-heading t t t t)))
             (when (string-match "\\`Feynman: \\(.+\\)\\'" heading)
               (let* ((topic (match-string 1 heading))
                      (id (org-entry-get (point) "ID"))
                      (old (gethash topic latest)))
                 (when (and id
                            (string-match-p
                             "\\`feynman-[0-9]\\{14\\}\\'" id)
                            (or (null old)
                                (string> id (plist-get old :id))))
                   (puthash
                    topic
                    (list :topic topic :id id
                          :domain (org-entry-get (point) "DOMAIN")
                          :mode (org-entry-get (point) "MODE")
                          :acc (org-entry-get (point) "ACC")
                          :simp (org-entry-get (point) "SIMP")
                          :cov (org-entry-get (point) "COV")
                          :scheduled (feynman--scheduled))
                    latest)))))))))
    (let (entries)
      (maphash (lambda (_topic entry) (push entry entries)) latest)
      entries)))

(defun feynman--markers (entry)
  "ENTRYのACC・SIMP・COVを連結した評価マーカーを返す。"
  (concat (or (plist-get entry :acc) "?")
          (or (plist-get entry :simp) "?")
          (or (plist-get entry :cov) "?")))

(defun feynman--scheduled-day (entry)
  "ENTRYのSCHEDULEDを通算日に変換する。"
  (when-let ((scheduled (plist-get entry :scheduled)))
    (time-to-days (org-time-string-to-time scheduled))))

(defun feynman--due-entries ()
  "復習期日が今日以前の最新エントリを超過日数順で返す。"
  (let ((today (time-to-days (current-time)))
        due)
    (dolist (entry (feynman--entries))
      (when-let ((day (feynman--scheduled-day entry)))
        (when (<= day today)
          (push (plist-put entry :overdue (- today day)) due))))
    (sort due (lambda (a b)
                (> (plist-get a :overdue) (plist-get b :overdue))))))

(defun feynman--frontier ()
  "hard領域のREADYノードをツリー間ラウンドロビンで返す。"
  (when (require 'skilltree-menu nil t)
    (pcase-let* ((`(,acquired . ,nodes) (skilltree--scan))
                 (labels (mapcar #'car
                                 (cl-remove-if-not
                                  (lambda (tree) (eq (nth 2 tree) 'hard))
                                  skilltree-trees)))
                 (queues
                  (mapcar
                   (lambda (label)
                     (cons label
                           (cl-remove-if-not
                            (lambda (node)
                              (and (equal (plist-get node :label) label)
                                   (eq (skilltree--ready-status node acquired)
                                       'ready)))
                            nodes)))
                   labels))
                 (result nil))
      (while (and (< (length result) feynman-frontier-limit)
                  (cl-some #'cdr queues))
        (dolist (queue queues)
          (when (and (cdr queue)
                     (< (length result) feynman-frontier-limit))
            (push (pop (cdr queue)) result))))
      (nreverse result))))

(defvar feynman-menu-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'feynman-menu-start-at-point)
    (define-key map (kbd "s") #'feynman-start)
    (define-key map (kbd "g") #'feynman-menu)
    (define-key map (kbd "q") #'quit-window)
    map)
  "`feynman-menu-mode'のキーマップ。")

(define-minor-mode feynman-menu-mode
  "Feynmanメニューを操作するためのマイナーモード。"
  :lighter " Feynman"
  :keymap feynman-menu-mode-map
  (read-only-mode (if feynman-menu-mode 1 -1)))

(defun feynman--insert-candidate (text topic)
  "候補行TEXTを挿入し、TOPICをtext propertyとして付ける。"
  (let ((start (point)))
    (insert text "\n")
    (add-text-properties start (point)
                         `(feynman-topic ,topic rear-nonsticky t))))

(defun feynman-menu-start-at-point ()
  "現在行のトピックでFeynmanセッションを開始する。"
  (interactive)
  (if-let ((topic (or (get-text-property (point) 'feynman-topic)
                      (get-text-property (line-beginning-position)
                                         'feynman-topic))))
      (feynman--send-to-claude topic)
    (user-error "この行にはトピックがありません")))

;;;###autoload
(defun feynman-menu ()
  "復習期日とREADYフロンティアをメニュー表示する。"
  (interactive)
  (let ((due (feynman--due-entries))
        (frontier (feynman--frontier))
        (buf (get-buffer-create feynman--buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (org-mode)
        (insert (format "#+title: Feynman Menu %s\n\n"
                        (format-time-string "[%Y-%m-%d %a]")))
        (insert "* 復習期日到来\n")
        (if due
            (dolist (entry due)
              (feynman--insert-candidate
               (format "- %s  %s  %s  %s  %d日超過"
                       (plist-get entry :topic)
                       (or (plist-get entry :domain) "?")
                       (feynman--markers entry)
                       (plist-get entry :scheduled)
                       (plist-get entry :overdue))
               (plist-get entry :topic)))
          (insert "- 復習期日到来なし\n"))
        (insert "\n* 新規候補（READYフロンティア）\n")
        (if frontier
            (dolist (node frontier)
              (feynman--insert-candidate
               (format "- %s  %s"
                       (plist-get node :label)
                       (plist-get node :title))
               (plist-get node :title)))
          (insert "- 新規候補なし\n"))
        (insert "\nRET: セッション開始 / s: 自由入力 / g: 再描画 / q: 閉じる\n")
        (goto-char (point-min))
        (feynman-menu-mode 1)))
    (pop-to-buffer buf)))

(defun feynman--completion-data ()
  "`feynman-start'用の候補と注釈を返す。"
  (let (candidates annotations)
    (dolist (entry (feynman--due-entries))
      (let ((topic (plist-get entry :topic)))
        (push topic candidates)
        (push (cons topic
                    (format "  復習 %s %d日超過"
                            (feynman--markers entry)
                            (plist-get entry :overdue)))
              annotations)))
    (dolist (node (feynman--frontier))
      (let ((topic (plist-get node :title)))
        (unless (member topic candidates)
          (push topic candidates)
          (push (cons topic
                      (format "  新規 %s" (plist-get node :label)))
                annotations))))
    (cons (nreverse candidates) annotations)))

;;;###autoload
(defun feynman-start ()
  "候補または自由入力からトピックを選びFeynmanセッションを開始する。"
  (interactive)
  (pcase-let* ((`(,candidates . ,annotations) (feynman--completion-data))
               (completion-extra-properties
                `(:annotation-function
                  ,(lambda (candidate)
                     (cdr (assoc candidate annotations)))))
               (topic (string-trim
                       (completing-read "Feynmanトピック: " candidates
                                        nil nil))))
    (when (string-empty-p topic)
      (user-error "トピックを入力してください"))
    (feynman--send-to-claude topic)))

(defun feynman--display-terminal (buffer)
  "端末BUFFERを右サイドウィンドウに表示する。"
  (display-buffer-in-side-window
   buffer '((side . right) (window-width . 0.42) (slot . 1))))

(defun feynman--terminal-send (buffer text)
  "端末BUFFERへTEXTを送信し、Enterで確定する。
claude CLIのTUIは\\n(C-j)を改行挿入と解釈するため、確定はCRで送る。"
  (with-current-buffer buffer
    (pcase feynman--terminal-type
      ('vterm (vterm-send-string text)
              (vterm-send-return))
      ('eat (eat-term-send-string eat-terminal (concat text "\r")))
      (_ (user-error "Feynman端末の種別を判定できません")))))

(defun feynman--start-terminal ()
  "Feynman専用端末を起動し、そのバッファを返す。"
  (let ((default-directory (file-name-as-directory
                            (expand-file-name feynman-claude-directory)))
        buffer)
    (cond
     ((require 'vterm nil t)
      (setq buffer (vterm feynman--terminal-buffer-name))
      (with-current-buffer buffer
        (setq feynman--terminal-type 'vterm)))
     ((require 'eat nil t)
      (save-window-excursion
        (let ((result (eat)))
          (setq buffer (if (bufferp result) result (current-buffer)))))
      (with-current-buffer buffer
        (rename-buffer feynman--terminal-buffer-name t)
        (setq feynman--terminal-type 'eat)))
     (t
      (user-error "vtermまたはeatをインストールしてください")))
    buffer))

(defun feynman--send-to-claude (topic)
  "Claude Codeへ「/feynman TOPIC」を送信する。"
  (let ((buffer (get-buffer feynman--terminal-buffer-name)))
    (if (buffer-live-p buffer)
        (feynman--terminal-send buffer (format "/feynman %s" topic))
      (setq buffer (feynman--start-terminal))
      (feynman--terminal-send buffer "claude")
      (run-at-time
       feynman-claude-startup-delay nil
       (lambda (buf command)
         (when (buffer-live-p buf)
           (feynman--terminal-send buf command)))
       buffer (format "/feynman %s" topic)))
    (feynman--display-terminal buffer)))

(provide 'feynman)
;;; feynman.el ends here
