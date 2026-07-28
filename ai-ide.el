;;; ai-ide.el --- Emacs as an AI IDE surface  -*- lexical-binding: t; -*-

;; Version: 0.1.1
;; Package-Requires: ((emacs "29.1"))

;;; Commentary:

;; エージェント (Claude Code / Codex CLI / 任意) が編集イベントを JSON で
;; spool ディレクトリに落とし、Emacs が file-notify で拾う。一方向・疎結合。
;; エージェント側は「1 ファイル書いて mv するだけ」なので数 ms で返る。
;;
;;   agent --hook--> ~/.cache/ai-ide/spool/*.json --file-notify--> Emacs
;;                       + history.jsonl (追記のみ / 日報の材料)
;;
;; 4 レイヤ:
;;   SYNC     バッファ追従。point / undo / marker / overlay を壊さない
;;   MARK     AI が書いた領域を overlay で可視化・巡回・クリア
;;   DIFF     git tree object による checkpoint と差分 (コミットを作らない)
;;   JOURNAL  セッションの digest を org-journal に落とす
;;
;; 使い方:
;;   (require 'ai-ide)
;;   (ai-ide-mode 1)
;;   C-c i c  checkpoint     ; エージェントを走らせる前に打つ
;;   C-c i d  diff           ; checkpoint からの差分
;;   C-c i j  journal        ; 日報に digest を追記
;;   C-c i n / p             ; AI の編集箇所を巡回
;;   C-c i k  clear marks
;;   C-c i l  list events

;;; Code:

(require 'cl-lib)
(require 'filenotify)
(require 'project)
(require 'seq)
(require 'subr-x)

(defgroup ai-ide nil
  "Follow AI agent edits inside Emacs."
  :group 'tools
  :prefix "ai-ide-")

;;;; ------------------------------------------------------------------ config

(defcustom ai-ide-home
  (expand-file-name "ai-ide/"
                    (or (getenv "XDG_CACHE_HOME") (expand-file-name "~/.cache/")))
  "イベントの受け口。高頻度・使い捨てなので Dropbox の外に置くこと。"
  :type 'directory)

(defcustom ai-ide-ai-dir (expand-file-name "~/Dropbox/AI/")
  "AI 共有記憶層のルート。digest のミラー先。"
  :type 'directory)

(defcustom ai-ide-sync 'fine-grain
  "ディスク上の変更をバッファに取り込む方法。
`fine-grain' は `replace-buffer-contents' 経由なので point・undo 履歴・
marker・overlay が生き残る。`revert' は素の revert-buffer。nil で無効。"
  :type '(choice (const :tag "fine-grain (推奨)" fine-grain)
                 (const :tag "revert-buffer" revert)
                 (const :tag "無効" nil)))

(defcustom ai-ide-mark-edits t
  "AI が書いた領域に overlay を置くか。"
  :type 'boolean)

(defcustom ai-ide-journal-level 2
  "日報に挿入する見出しのレベル。"
  :type 'integer)

(defcustom ai-ide-journal-tags ":ai:"
  "日報見出しに付けるタグ。nil で無効。"
  :type '(choice string (const nil)))

(defcustom ai-ide-journal-function #'ai-ide-journal-org-journal
  "digest 文字列を受け取って書き込む関数。"
  :type 'function)

(defcustom ai-ide-poll-interval 5
  "file-notify が効かない環境 (WSL / ネットワーク FS) 用の保険。nil で無効。"
  :type '(choice integer (const nil)))

(defcustom ai-ide-notify-function #'ai-ide--echo
  "編集イベント 1 件ごとに呼ばれる通知関数。引数はイベント plist。"
  :type 'function)

(defface ai-ide-edit-face
  '((((background dark))  :background "#14261c" :extend t)
    (((background light)) :background "#e6f4ea" :extend t))
  "AI が書き込んだ領域。")

;;;; ------------------------------------------------------------------- state

(defvar ai-ide--watch nil)
(defvar ai-ide--timer nil)
(defvar ai-ide--events nil
  "新しい順のイベント plist リスト: :ts :agent :session :tool :file :root.")
(defvar ai-ide--checkpoints (make-hash-table :test #'equal)
  "project root -> git tree object SHA.")
(defvar ai-ide--conflicts nil
  "未保存バッファと衝突したファイルのリスト。")
(defvar-local ai-ide--overlays nil)
(defvar ai-ide--lighter "")

(defun ai-ide--spool () (expand-file-name "spool/" ai-ide-home))
(defun ai-ide--history () (expand-file-name "history.jsonl" ai-ide-home))

;;;; -------------------------------------------------------------------- util

(defun ai-ide--root (&optional dir)
  "DIR (既定 `default-directory') を含むプロジェクトルートを返す。"
  (let ((dir (or dir default-directory)))
    (file-name-as-directory
     (expand-file-name
      (or (when-let* ((p (project-current nil dir))) (project-root p))
          (locate-dominating-file dir ".git")
          dir)))))

(defun ai-ide--git (root &rest args)
  "ROOT で git ARGS を実行し stdout を返す。"
  (let ((default-directory (file-name-as-directory root)))
    (with-output-to-string
      (with-current-buffer standard-output
        (apply #'process-file "git" nil (list t nil) nil args)))))

(defun ai-ide--echo (ev)
  (message "ai-ide: %s %s %s"
           (plist-get ev :agent)
           (plist-get ev :tool)
           (file-name-nondirectory (plist-get ev :file))))

;;;; ------------------------------------------------------------------ ingest

(defun ai-ide--drain (&rest _)
  "spool のイベントファイルを全部読んで処理し、削除する。"
  (let ((spool (ai-ide--spool)))
    (when (file-directory-p spool)
      (dolist (f (sort (directory-files spool t "\\.json\\'") #'string<))
        (let ((ev (condition-case nil
                      (with-temp-buffer
                        (insert-file-contents f)
                        (json-parse-string (buffer-string)
                                           :object-type 'plist
                                           :null-object nil
                                           :false-object nil))
                    (error nil))))
          (ignore-errors (delete-file f))
          (when ev
            (condition-case err (ai-ide--handle ev)
              (error (message "ai-ide: handle failed: %S" err)))))))))

(defun ai-ide--handle (raw)
  "エージェント由来の RAW plist を 1 件処理する。"
  (let* ((input (plist-get raw :tool_input))
         (tool  (or (plist-get raw :tool_name) ""))
         (file  (and input (or (plist-get input :file_path)
                               (plist-get input :notebook_path))))
         (file  (and file (expand-file-name file)))
         (agent (or (plist-get raw :agent) "?"))
         (news  (ai-ide--new-strings tool input)))
    (when (and file (file-exists-p file))
      (let ((ev (list :ts (format-time-string "%H:%M:%S")
                      :time (current-time)
                      :agent agent
                      :session (plist-get raw :session_id)
                      :tool tool
                      :file file
                      :root (ai-ide--root (file-name-directory file)))))
        (push ev ai-ide--events)
        (let ((buf (ai-ide--sync file)))
          (when (and buf ai-ide-mark-edits) (ai-ide--mark buf tool news)))
        (ai-ide--update-lighter)
        (when ai-ide-notify-function (funcall ai-ide-notify-function ev))))))

(defun ai-ide--new-strings (tool input)
  "TOOL / INPUT から「新しく書かれた文字列」のリストを取り出す。"
  (cond
   ((null input) nil)
   ((plist-get input :edits)            ; MultiEdit
    (seq-keep (lambda (e) (plist-get e :new_string)) (plist-get input :edits)))
   ((plist-get input :new_string) (list (plist-get input :new_string)))
   ((member tool '("Write" "create_file")) 'whole)
   (t nil)))

;;;; -------------------------------------------------------------------- sync

(defun ai-ide--sync (file)
  "FILE を訪問中のバッファをディスクに追従させる。成功時バッファを返す。"
  (when-let* ((buf (find-buffer-visiting file)))
    (with-current-buffer buf
      (cond
       ((null ai-ide-sync) buf)
       ((buffer-modified-p)
        (cl-pushnew file ai-ide--conflicts :test #'equal)
        (message "ai-ide: %s は未保存 — M-x ai-ide-resolve-conflict"
                 (file-name-nondirectory file))
        nil)
       (t
        (let ((inhibit-message t))
          (if (and (eq ai-ide-sync 'fine-grain)
                   (fboundp 'revert-buffer-with-fine-grain))
              (revert-buffer-with-fine-grain t t)
            (revert-buffer :ignore-auto :noconfirm :preserve-modes)))
        buf)))))

(defun ai-ide-resolve-conflict ()
  "衝突したファイルをバッファ vs ディスクの ediff で開く。"
  (interactive)
  (unless ai-ide--conflicts (user-error "衝突はありません"))
  (let* ((file (completing-read "衝突ファイル: " ai-ide--conflicts nil t))
         (buf  (find-buffer-visiting file)))
    (setq ai-ide--conflicts (delete file ai-ide--conflicts))
    (if buf
        ;; find-file-noselect は訪問中のバッファ自身を返すため、
        ;; バッファ vs ディスクの比較は ediff-current-file で行う
        (with-current-buffer buf (ediff-current-file))
      (find-file file))))

;;;; -------------------------------------------------------------------- mark

(defun ai-ide--overlay (beg end)
  (let ((ov (make-overlay beg end nil nil t)))
    (overlay-put ov 'face 'ai-ide-edit-face)
    (overlay-put ov 'ai-ide t)
    (overlay-put ov 'priority -50)
    (push ov ai-ide--overlays)
    ov))

(defun ai-ide--mark (buf tool news)
  (with-current-buffer buf
    (cond
     ((eq news 'whole) (ai-ide--overlay (point-min) (point-max)))
     ((listp news)
      (save-excursion
        (dolist (s news)
          (when (and (stringp s) (not (string-empty-p s)))
            (goto-char (point-min))
            (when (search-forward s nil t)
              (ai-ide--overlay (match-beginning 0) (match-end 0)))))))))
  (ignore tool))

(defun ai-ide--marks ()
  (seq-filter (lambda (o) (and (overlay-buffer o) (overlay-get o 'ai-ide)))
              ai-ide--overlays))

(defun ai-ide-next-mark ()
  "次の AI 編集箇所へ。"
  (interactive)
  (let* ((starts (sort (mapcar #'overlay-start (ai-ide--marks)) #'<))
         (next (seq-find (lambda (p) (> p (point))) starts)))
    (if next (progn (goto-char next) (recenter))
      (message "ai-ide: これ以降に AI の編集はありません"))))

(defun ai-ide-prev-mark ()
  "前の AI 編集箇所へ。"
  (interactive)
  (let* ((starts (sort (mapcar #'overlay-start (ai-ide--marks)) #'>))
         (prev (seq-find (lambda (p) (< p (point))) starts)))
    (if prev (progn (goto-char prev) (recenter))
      (message "ai-ide: これ以前に AI の編集はありません"))))

(defun ai-ide-clear-marks (&optional all)
  "このバッファのマークを消す。ALL (C-u) で全バッファ。"
  (interactive "P")
  (dolist (buf (if all (buffer-list) (list (current-buffer))))
    (with-current-buffer buf
      (mapc #'delete-overlay ai-ide--overlays)
      (setq ai-ide--overlays nil))))

;;;; ---------------------------------------------------- checkpoint  and  diff

(defun ai-ide--git-chain (root idx buf cmds callback)
  "ROOT で git CMDS を非同期に順番に実行し、完了後 CALLBACK を呼ぶ。
stdout は BUF に溜まる。個々のコマンドの失敗では止まらない
(read-tree HEAD は空リポジトリでは失敗してよいため)。"
  (if (null cmds)
      (funcall callback)
    (let ((default-directory (file-name-as-directory root))
          (process-environment (cons (concat "GIT_INDEX_FILE=" idx)
                                     process-environment)))
      (make-process
       :name "ai-ide-git"
       :buffer buf
       :noquery t
       :command (cons "git" (car cmds))
       :stderr (get-buffer-create " *ai-ide-git-stderr*")
       :sentinel (lambda (p _ev)
                   (when (memq (process-status p) '(exit signal))
                     (ai-ide--git-chain root idx buf (cdr cmds) callback)))))))

(defun ai-ide-checkpoint (&optional root)
  "ワークツリーを detached な git tree object として保存する。
コミットもインデックス変更もしないので履歴を汚さない。
大きなワークツリーの add -A で Emacs が固まらないよう git は非同期に走り、
完了はエコーエリアに通知される。"
  (interactive)
  (let ((root (or root (ai-ide--root))))
    (unless (locate-dominating-file root ".git")
      (user-error "ai-ide: %s は git リポジトリではありません" root))
    (let ((idx (make-temp-file "ai-ide-index"))
          (buf (generate-new-buffer " *ai-ide-checkpoint*")))
      (delete-file idx)                 ; git に作らせる (0 byte だと壊れる)
      (message "ai-ide: checkpoint 作成中... (%s)"
               (file-name-nondirectory (directory-file-name root)))
      (ai-ide--git-chain
       root idx buf
       '(("read-tree" "HEAD") ("add" "-A") ("write-tree"))
       (lambda ()
         (let ((out (with-current-buffer buf (buffer-string))))
           (kill-buffer buf)
           (ignore-errors (delete-file idx))
           (if (string-match "\\([0-9a-f]\\{40,\\}\\)[ \t\n]*\\'" out)
               (let ((tree (match-string 1 out)))
                 (puthash root tree ai-ide--checkpoints)
                 (message "ai-ide: checkpoint %s (%s)"
                          (substring tree 0 8)
                          (file-name-nondirectory (directory-file-name root))))
             (message "ai-ide: checkpoint 失敗: %s" (string-trim out)))))))))

(defun ai-ide--tree (root)
  (or (gethash root ai-ide--checkpoints)
      (user-error "ai-ide: checkpoint がありません。先に M-x ai-ide-checkpoint")))

(defun ai-ide-diff (&optional root)
  "checkpoint 以降に AI が変えたものを表示する。
`git diff <tree>' は未追跡ファイルを「削除」として見せてしまうため、
現在のワークツリーも一時インデックスで tree 化して tree 同士を比較する
(準備は checkpoint と同じく非同期)。表示は diff-mode で、
`diff-font-lock-syntax' により元言語のシンタックスハイライトが付く。"
  (interactive)
  (let* ((root (or root (ai-ide--root)))
         (tree (ai-ide--tree root))
         (idx  (make-temp-file "ai-ide-index"))
         (obuf (generate-new-buffer " *ai-ide-diff-tree*")))
    (delete-file idx)
    (message "ai-ide: 差分を準備中... (%s)"
             (file-name-nondirectory (directory-file-name root)))
    (ai-ide--git-chain
     root idx obuf
     '(("read-tree" "HEAD") ("add" "-A") ("write-tree"))
     (lambda ()
       (let ((out (with-current-buffer obuf (buffer-string))))
         (kill-buffer obuf)
         (ignore-errors (delete-file idx))
         (if (not (string-match "\\([0-9a-f]\\{40,\\}\\)[ \t\n]*\\'" out))
             (message "ai-ide: 差分の準備に失敗: %s" (string-trim out))
           (let ((now (match-string 1 out))
                 (buf (get-buffer-create "*ai-ide-diff*")))
             (with-current-buffer buf
               (let ((inhibit-read-only t)
                     (default-directory root))
                 (erase-buffer)
                 ;; --no-ext-diff: diff.external (difftastic等) を無視して
                 ;;   diff-mode が読める unified diff を得る
                 ;; --no-prefix: a/ b/ を外す。diff-mode の構文ハイライトは
                 ;;   ファイル名が実ファイルに解決できるときだけ効く
                 (insert (ai-ide--git root "diff" "--no-ext-diff" "--no-prefix"
                                      "-p" tree now))
                 ;; diff-mode はモード起動時に read-only だと単キーマップを
                 ;; 有効化する (q=閉じる / n・p=ハンク移動 / RET=該当箇所へ)。
                 ;; そのため diff-mode より先に read-only にする
                 (setq buffer-read-only t)
                 (diff-mode)
                 (setq default-directory root)
                 (setq-local diff-default-directory root)
                 (goto-char (point-min))))
             (if (zerop (buffer-size buf))
                 (progn (kill-buffer buf)
                        (message "ai-ide: checkpoint から変更はありません"))
               (pop-to-buffer buf)
               (message "ai-ide: hunk を捨てるなら C-u C-c C-a (diff-apply-hunk 逆適用)")))))))))

(defun ai-ide-diff-file ()
  "現在のファイルだけ checkpoint と ediff する。"
  (interactive)
  (let* ((file (or buffer-file-name (user-error "ファイルバッファではありません")))
         (root (ai-ide--root (file-name-directory file)))
         (tree (ai-ide--tree root))
         (rel  (file-relative-name file root))
         (old  (get-buffer-create (format "*checkpoint: %s*" rel))))
    (with-current-buffer old
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (ai-ide--git root "show" (concat tree ":" rel)))
        (setq buffer-read-only t)))
    (ediff-buffers old (current-buffer))))

;;;; ----------------------------------------------------------------- journal

(defun ai-ide--digest (root)
  "ROOT 配下の (FILE . COUNT) を編集数降順で返す。"
  (let ((tbl (make-hash-table :test #'equal)) acc)
    (dolist (ev ai-ide--events)
      (when (string-prefix-p root (plist-get ev :file))
        (let ((f (plist-get ev :file)))
          (puthash f (1+ (gethash f tbl 0)) tbl))))
    (maphash (lambda (k v) (push (cons k v) acc)) tbl)
    (sort acc (lambda (a b) (> (cdr a) (cdr b))))))

(defun ai-ide--org-entry (root)
  "ROOT の digest を org のサブツリー文字列にする。"
  (let* ((digest (ai-ide--digest root))
         (tree   (gethash root ai-ide--checkpoints))
         (stat   (when tree (string-trim (ai-ide--git root "diff" "--no-ext-diff" "--stat" tree))))
         (agents (delete-dups
                  (mapcar (lambda (e) (plist-get e :agent))
                          (seq-filter (lambda (e) (string-prefix-p root (plist-get e :file)))
                                      ai-ide--events)))))
    (when (null digest) (user-error "ai-ide: 記録すべき編集がありません"))
    (concat
     (make-string ai-ide-journal-level ?*) " AI編集 "
     (format-time-string "[%Y-%m-%d %a %H:%M]")
     (if ai-ide-journal-tags (concat "  " ai-ide-journal-tags) "") "\n"
     ":PROPERTIES:\n"
     ":AI_PROJECT: " (file-name-nondirectory (directory-file-name root)) "\n"
     ":AI_AGENTS: "  (string-join agents ", ") "\n"
     ":AI_FILES: "   (number-to-string (length digest)) "\n"
     ":AI_EDITS: "   (number-to-string (apply #'+ (mapcar #'cdr digest))) "\n"
     (if tree (concat ":AI_CHECKPOINT: " (substring tree 0 8) "\n") "")
     ":END:\n"
     "| file | edits |\n|---+---|\n"
     (mapconcat (lambda (c) (format "| %s | %d |" (file-relative-name (car c) root) (cdr c)))
                digest "\n")
     "\n"
     (if (and stat (not (string-empty-p stat)))
         (concat "#+begin_example\n" stat "\n#+end_example\n") ""))))

(defun ai-ide-journal-org-journal (text)
  "TEXT を今日の org-journal ファイルの末尾に追記する。"
  (require 'org-journal nil t)
  (unless (fboundp 'org-journal-new-entry)
    (user-error "org-journal がありません。ai-ide-journal-function を差し替えてください"))
  (save-window-excursion
    (org-journal-new-entry t)           ; 時刻見出しを作らずに今日のファイルを開く
    (goto-char (point-max))
    (unless (bolp) (insert "\n"))
    (insert text)
    (when (buffer-file-name) (save-buffer))))

(defun ai-ide-journal-into-ai-inbox (text)
  "TEXT を /AI/inbox/ に新規ファイルとして落とす (共有記憶層側)。"
  (let* ((dir (expand-file-name "inbox/" ai-ide-ai-dir))
         (file (expand-file-name
                (format-time-string "%Y%m%d%H%M%S-ai-edits.org") dir)))
    (make-directory dir t)
    (with-temp-file file
      (insert "#+title: AI編集ログ " (format-time-string "%F") "\n"
              "#+filetags: :ai:log:\n\n" text))
    (message "ai-ide: %s" file)))

(defun ai-ide-journal ()
  "今日の AI 編集 digest を日報に記録する。"
  (interactive)
  (funcall ai-ide-journal-function (ai-ide--org-entry (ai-ide--root)))
  (message "ai-ide: journal に記録しました"))

;;;; -------------------------------------------------------------------- list

(defun ai-ide-list ()
  "直近の AI 編集イベントを一覧する。"
  (interactive)
  (let ((buf (get-buffer-create "*ai-ide events*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (dolist (ev (seq-take ai-ide--events 200))
          (insert (format "%s  %-8s %-10s %s\n"
                          (plist-get ev :ts)
                          (plist-get ev :agent)
                          (plist-get ev :tool)
                          (abbreviate-file-name (plist-get ev :file)))))
        (goto-char (point-min))
        (special-mode)))
    (pop-to-buffer buf)))

;;;; -------------------------------------------------------------------- mode

(defun ai-ide--update-lighter ()
  (setq ai-ide--lighter (format " AI:%d" (length ai-ide--events)))
  (force-mode-line-update t))

(defvar-keymap ai-ide-command-map
  :doc "ai-ide prefix map."
  "c" #'ai-ide-checkpoint
  "d" #'ai-ide-diff
  "D" #'ai-ide-diff-file
  "j" #'ai-ide-journal
  "l" #'ai-ide-list
  "n" #'ai-ide-next-mark
  "p" #'ai-ide-prev-mark
  "k" #'ai-ide-clear-marks
  "r" #'ai-ide-resolve-conflict)

;; C-c a は org-agenda が使用中 (config.org) のため C-c i
(defvar-keymap ai-ide-mode-map
  "C-c i" ai-ide-command-map)

;;;###autoload
(define-minor-mode ai-ide-mode
  "エージェントの編集を Emacs に流し込むグローバルマイナーモード。"
  :global t
  :lighter ai-ide--lighter
  :keymap ai-ide-mode-map
  (if ai-ide-mode (ai-ide--start) (ai-ide--stop)))

(defun ai-ide--start ()
  (make-directory (ai-ide--spool) t)
  (setq ai-ide--watch
        (ignore-errors
          (file-notify-add-watch (ai-ide--spool) '(change) #'ai-ide--drain)))
  (when (and ai-ide-poll-interval (null ai-ide--timer))
    (setq ai-ide--timer (run-at-time 2 ai-ide-poll-interval #'ai-ide--drain)))
  (ai-ide--drain))

(defun ai-ide--stop ()
  (when ai-ide--watch (ignore-errors (file-notify-rm-watch ai-ide--watch)))
  (when ai-ide--timer (cancel-timer ai-ide--timer))
  (setq ai-ide--watch nil ai-ide--timer nil))

(provide 'ai-ide)
;;; ai-ide.el ends here
