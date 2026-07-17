;;; skilltree-menu.el --- SkillTreeSystem 今日のrunメニュー -*- lexical-binding: t; -*-

;; 位置づけ:
;;   「次に何をしたらいいのか」を AIなし・オフライン・即時 で答える供給層。
;;   - ハード領域 (GenArt / DTM / Systems): READYフロンティアを動的算出
;;       READY = 未取得(:ACQUIRED: なし) ∧ :REQUIRES: 先がすべて取得済み
;;       (:REQUIRES: なしの未取得ノードは常にREADY = グラフの入口)
;;   - ソフト領域 (SF6 / Illust): 未解決PROBLEM + :EXIT: を列挙
;;       EXIT未記入は ⚠ で可視化(行動に落ちない負債として毎回目に入れる)
;;   朝ランのAIはこの出力の「編集者」。供給源はこのコマンド。
;;
;; セットアップ:
;;   (setq skilltree-directory "~/Dropbox/Org/") ; org-roam-directory と違う場合のみ
;;   (require 'skilltree-menu)
;;   (global-set-key (kbd "C-c r") #'skilltree-run-menu) ; 任意
;;
;; 使い方:
;;   M-x skilltree-run-menu
;;   リンクは C-c C-o で該当ノードへジャンプ(org-roamのid解決に乗る)。

;;; Code:

(require 'org)
(require 'org-id)
(require 'cl-lib)
(require 'subr-x)

(defgroup skilltree nil
  "SkillTreeSystem run menu."
  :group 'org
  :prefix "skilltree-")

(defcustom skilltree-directory
  (or (bound-and-true-p org-roam-directory) "~/Dropbox/Org/")
  "SkillTreeのツリーファイルが置かれているディレクトリ。"
  :type 'directory
  :group 'skilltree)

(defcustom skilltree-trees
  '(("GenArt"  "20260707100001-genartskilltree.org"    hard)
    ("DTM"     "20260707100000-dtmskilltree.org"       hard)
    ("Systems" "20260716100000-systemsskilltree.org"   hard)
    ("SF6"     "20240121181134-streetfigter6tree.org"  soft)
    ("Illust"  "20240110193026-illustskilltree.org"    soft))
  "ツリー定義。各要素は (ラベル ファイル名 hard|soft)。
hard = READYフロンティア算出 / soft = 未解決PROBLEM+EXIT列挙。"
  :type '(repeat (list (string :tag "Label")
                       (string :tag "File name")
                       (choice (const hard) (const soft))))
  :group 'skilltree)

(defconst skilltree--buffer-name "*SkillTree Run Menu*")

(defun skilltree--file (name)
  "NAME を `skilltree-directory' 配下の絶対パスへ。"
  (expand-file-name name skilltree-directory))

(defun skilltree--requires-ids (val)
  ":REQUIRES: プロパティ VAL から id: リンク先IDを抽出する。"
  (let ((pos 0) ids)
    (while (and val (string-match "id:\\([[:alnum:]-]+\\)" val pos))
      (push (match-string 1 val) ids)
      (setq pos (match-end 0)))
    (nreverse ids)))

(defun skilltree--scan ()
  "全ツリーを走査し (ACQUIRED-TABLE . NODES) を返す。
ACQUIRED-TABLE: id → 取得済みなら t。
NODES: 各見出しの plist のリスト。"
  (let ((acquired (make-hash-table :test #'equal))
        nodes)
    (dolist (tree skilltree-trees)
      (pcase-let ((`(,label ,fname ,mode) tree))
        (let ((file (skilltree--file fname)))
          (if (not (file-exists-p file))
              (message "skilltree: ファイルが見つかりません: %s" file)
            (with-current-buffer (find-file-noselect file)
              (org-with-wide-buffer
               (goto-char (point-min))
               (while (re-search-forward org-heading-regexp nil t)
                 (let ((id    (org-entry-get (point) "ID"))
                       (acq   (org-entry-get (point) "ACQUIRED"))
                       (todo  (org-get-todo-state))
                       (exit  (org-entry-get (point) "EXIT"))
                       (req   (skilltree--requires-ids
                               (org-entry-get (point) "REQUIRES")))
                       (title (org-get-heading t t t t))
                       (path  (org-get-outline-path)))
                   (when id
                     (puthash id (and acq t) acquired))
                   (push (list :label label :mode mode :id id
                               :acquired acq :todo todo :exit exit
                               :req req :title title :path path)
                         nodes)))))))))
    (cons acquired (nreverse nodes))))

(defun skilltree--link (node)
  "NODE をorgリンク文字列に。:ID: が無ければプレーンテキスト。"
  (let ((id (plist-get node :id))
        (title (plist-get node :title)))
    (if id (format "[[id:%s][%s]]" id title) (or title "?"))))

(defun skilltree--context (node)
  "親見出しまでのパス文字列。トップレベルなら nil。"
  (let ((path (plist-get node :path)))
    (when path (string-join path " ＞ "))))

(defun skilltree--ready-status (node acquired)
  "hard領域の学習候補ノードの状態を返す。
ready / blocked / (broken . 未知ID列) / nil(対象外)。
対象 = todo が PROBLEM かつ :ACQUIRED: 無し
(コアスキル等の構造ノードを除外するための条件)。"
  (when (and (eq (plist-get node :mode) 'hard)
             (equal (plist-get node :todo) "PROBLEM")
             (not (plist-get node :acquired)))
    (let (unknown unmet)
      (dolist (rid (plist-get node :req))
        (let ((v (gethash rid acquired 'missing)))
          (cond ((eq v 'missing) (push rid unknown))
                ((not v)         (push rid unmet)))))
      (cond (unknown (cons 'broken (nreverse unknown)))
            (unmet   'blocked)
            (t       'ready)))))

;;;###autoload
(defun skilltree-run-menu ()
  "今日のrunメニューを表示する。
READYフロンティア(ハード領域) + 未解決PROBLEM(ソフト領域)。"
  (interactive)
  (pcase-let ((`(,acquired . ,nodes) (skilltree--scan)))
    (let ((buf (get-buffer-create skilltree--buffer-name))
          (broken '())
          (debt 0))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (org-mode)
          (insert (format "#+title: 今日のrunメニュー %s\n\n"
                          (format-time-string "[%Y-%m-%d %a]")))
          ;; --- ハード領域: READYフロンティア ---
          (insert "* READYフロンティア(ハード領域)\n")
          (dolist (tree skilltree-trees)
            (pcase-let ((`(,label ,_ ,mode) tree))
              (when (eq mode 'hard)
                (let ((mine (cl-remove-if-not
                             (lambda (n) (equal (plist-get n :label) label))
                             nodes))
                      (ready '())
                      (total 0))
                  (dolist (n mine)
                    (let ((st (skilltree--ready-status n acquired)))
                      (when st (cl-incf total))
                      (cond ((eq st 'ready) (push n ready))
                            ((and (consp st) (eq (car st) 'broken))
                             (push (cons n (cdr st)) broken)))))
                  (setq ready (nreverse ready))
                  (insert (format "** %s  (READY %d / 未取得 %d)\n"
                                  label (length ready) total))
                  (if (null ready)
                      (insert "- READYなし\n")
                    (dolist (n ready)
                      (let ((ctx (skilltree--context n)))
                        (insert (format "- %s%s\n"
                                        (if ctx (concat ctx " ＞ ") "")
                                        (skilltree--link n))))))))))
          ;; --- ソフト領域: 未解決PROBLEM + EXIT ---
          (insert "\n* 未解決PROBLEM(ソフト領域)\n")
          (dolist (tree skilltree-trees)
            (pcase-let ((`(,label ,_ ,mode) tree))
              (when (eq mode 'soft)
                (insert (format "** %s\n" label))
                (let ((probs (cl-remove-if-not
                              (lambda (n)
                                (and (equal (plist-get n :label) label)
                                     (equal (plist-get n :todo) "PROBLEM")))
                              nodes)))
                  (if (null probs)
                      (insert "- 未解決PROBLEMなし\n")
                    (dolist (n probs)
                      (let ((ctx (skilltree--context n))
                            (exit (plist-get n :exit)))
                        (insert (format "- %s%s"
                                        (if ctx (concat ctx " ＞ ") "")
                                        (skilltree--link n)))
                        (if exit
                            (insert (format "\n  - EXIT: %s\n" exit))
                          (cl-incf debt)
                          (insert " ⚠EXIT未記入\n")))))))))
          ;; --- フッター ---
          (insert (format "\n* EXIT負債: %d件\n" debt))
          (when (> debt 0)
            (insert "⚠のPROBLEMはrunに落ちない。EXITを1行書くこと自体が今日のrun候補。\n"))
          (when broken
            (insert "\n* 整合性チェック(要修正)\n")
            (dolist (b (nreverse broken))
              (insert (format "- %s の :REQUIRES: に未知のID: %s\n"
                              (plist-get (car b) :title)
                              (string-join (cdr b) ", ")))))
          (goto-char (point-min)))
        (read-only-mode 1))
      (pop-to-buffer buf))))

(provide 'skilltree-menu)
;;; skilltree-menu.el ends here
