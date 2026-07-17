;;; consult-yt.el --- ConsultでYouTube検索 & 好きな方法で開く -*- lexical-binding: t; -*-

(require 'consult)
(require 'json)
(require 'subr-x)
(require 'url-parse)

(defgroup my/consult-youtube nil
  "Search YouTube with consult via yt-dlp."
  :group 'convenience)

(defcustom my/consult-youtube-yt-dlp-program "yt-dlp"
  "Path to yt-dlp executable."
  :type 'string)

(defcustom my/consult-youtube-max-results 50
  "Max number of results to fetch from YouTube."
  :type 'integer)

(defun my/consult-youtube--build-display (title ch dur)
  "候補表示用の見出し文字列を組み立てる。"
  (string-trim
   (concat
    (if (and dur (not (string-empty-p dur)))
        (format "[%s] " dur)
      "")
    title
    (if (and ch (not (string-empty-p ch)))
        (format " — %s" ch)
      ""))))

(defun my/consult-youtube--call (query)
  "QUERY を YouTube 検索URLにして yt-dlp で取得。(DISPLAY . URL) の alist を返す。"
  (unless (executable-find my/consult-youtube-yt-dlp-program)
    (user-error "yt-dlp が見つかりません: %s" my/consult-youtube-yt-dlp-program))
  (let* ((search-url (format "https://www.youtube.com/results?search_query=%s"
                             (url-hexify-string (encode-coding-string query 'utf-8))))
         (cmd (list my/consult-youtube-yt-dlp-program
                    "-j" "--flat-playlist"
                    ;; ★ 結果数を制限
                    "--playlist-end" (number-to-string my/consult-youtube-max-results)
                    ;; ★ 不要なメタデータを取得しない
                    "--no-warnings"
                    "--extractor-args" "youtube:skip=authcheck"
                    search-url))
         (process-environment (append '("PYTHONIOENCODING=utf-8" "PYTHONUTF8=1"
                                        "LANG=ja_JP.UTF-8" "LC_ALL=ja_JP.UTF-8")
                                      process-environment))
         (coding-system-for-read 'utf-8)
         (coding-system-for-write 'utf-8)
         (lines (apply #'process-lines cmd))
         (out nil))
    (dolist (line lines (nreverse out))
      (let* ((obj   (ignore-errors (json-parse-string line :object-type 'alist)))
             (id    (and obj (alist-get 'id obj)))
             (title (or (and obj (alist-get 'title obj)) ""))
             (ch    (or (and obj (alist-get 'uploader obj))
                        (and obj (alist-get 'channel obj))
                        ""))
             (dur   (or (and obj (alist-get 'duration_string obj))
                        (let ((sec (and obj (alist-get 'duration obj))))
                          (when (numberp sec) (format-seconds "%m:%02s" sec)))
                        ""))
             (url   (and id (concat "https://youtu.be/" id))))
        (when url
          (push (cons
                 (string-trim
                  (concat (if (and dur (not (string-empty-p dur))) (format "[%s] " dur) "")
                          title
                          (if (and ch (not (string-empty-p ch))) (format " — %s" ch) "")))
                 url)
                out))))))

(defun my/consult-youtube (&optional initial)
  "yt-dlp で YouTube を検索して、選択した動画を `browse-url' で開く。
リージョンがアクティブならそれを初期クエリに使う。"
  (interactive)
  (let* ((query (or initial
                    (when (use-region-p)
                      (buffer-substring-no-properties (region-beginning) (region-end)))
                    (read-string "YouTube 検索: ")))
         (pairs (my/consult-youtube--call query)))
    (when (null pairs)
      (user-error "該当なし"))
    (let* ((cands (mapcar #'car pairs))
           (sel   (consult--read cands
                                 :prompt "選択: "
                                 :require-match t
                                 :sort nil
                                 :category 'youtube))
           (url   (cdr (assoc sel pairs))))
      (browse-url url))))

;; あなたのオープナーを使うなら（既に設定済みなら不要）
;; (setq browse-url-browser-function #'my/open-youtube-choose-method)

;; キーバインド例:
(global-set-key (kbd "C-c y") #'my/consult-youtube)
