;;; yt-browse.el --- Browse YouTube search results -*- lexical-binding: t; -*-

(require 'browse-url)
(require 'button)
(require 'json)
(require 'subr-x)
(require 'url)

(defgroup my/youtube-browse nil
  "Browse YouTube search results via yt-dlp."
  :group 'convenience)

(defcustom my/youtube-browse-page-size 20
  "Number of YouTube search results fetched per page."
  :type 'integer
  :group 'my/youtube-browse)

(defcustom my/youtube-browse-yt-dlp-program "yt-dlp"
  "Path to the yt-dlp executable."
  :type 'string
  :group 'my/youtube-browse)

(defvar-local my/youtube-browse-query nil)
(defvar-local my/youtube-browse-source-url nil)
(defvar-local my/youtube-browse-next-start 1)
(defvar-local my/youtube-browse-loading nil)
(defvar-local my/youtube-browse-process nil)
(defvar-local my/youtube-browse-tail-marker nil)
(defvar-local my/youtube-browse-generation 0)

(defun my/youtube-browse--set-tail (text &optional action)
  "Replace the result-buffer tail with TEXT.
When ACTION is non-nil, make TEXT a button invoking ACTION."
  (let ((inhibit-read-only t)
        (marker my/youtube-browse-tail-marker))
    (when (marker-position marker)
      (save-excursion
        (delete-region marker (point-max))
        (set-marker-insertion-type marker nil)
        (goto-char marker)
        (if action
            (insert-text-button text 'action action 'follow-link t)
          (insert text))
        (insert "\n")
        (set-marker-insertion-type marker t)))))

(defun my/youtube-browse--thumbnail-callback
    (status target generation start end)
  "Replace the thumbnail placeholder in TARGET after retrieval.
STATUS is supplied by `url-retrieve'; GENERATION rejects stale callbacks,
and START and END delimit the placeholder."
  (let ((retrieval-buffer (current-buffer))
        image)
    (unwind-protect
        (progn
          (unless (plist-get status :error)
            (setq image
                  (ignore-errors
                    (goto-char (or (bound-and-true-p url-http-end-of-headers)
                                   (point-min)))
                    ;; ヘッダ終端マーカーは空行の改行手前を指すことがあり、
                    ;; 先頭に\nが混じると画像タイプ判定に失敗する
                    (skip-chars-forward "\r\n")
                    (create-image
                     (buffer-substring-no-properties (point) (point-max))
                     nil t :max-width 200))))
          (when (and (buffer-live-p target)
                     (marker-buffer start)
                     (marker-buffer end))
            (with-current-buffer target
              (when (= generation my/youtube-browse-generation)
                (let ((inhibit-read-only t))
                  (save-excursion
                    (delete-region start end)
                    (goto-char start)
                    (if image
                        (insert-image image "[thumbnail]")
                      (insert "[サムネイルを取得できません]"))))))))
      (when (buffer-live-p retrieval-buffer)
        (kill-buffer retrieval-buffer)))))

(defun my/youtube-browse--insert-entry (object generation)
  "Insert one YouTube result from OBJECT for GENERATION.
Return non-nil when OBJECT contains a video ID."
  (let ((id (alist-get 'id object)))
    (when id
      (let* ((title (or (alist-get 'title object) ""))
             (channel (or (alist-get 'uploader object)
                          (alist-get 'channel object)
                          ""))
             (duration (or (alist-get 'duration_string object)
                           (let ((seconds (alist-get 'duration object)))
                             (when (numberp seconds)
                               (format-seconds "%m:%02s" seconds)))
                           ""))
             (url (concat "https://youtu.be/" id))
             (text (string-trim
                    (concat
                     (if (and duration (not (string-empty-p duration)))
                         (format "[%s] " duration)
                       "")
                     title
                     (if (and channel (not (string-empty-p channel)))
                         (format " — %s" channel)
                       ""))))
             (target (current-buffer)))
        (let ((inhibit-read-only t))
          (save-excursion
            (goto-char my/youtube-browse-tail-marker)
            (when (display-images-p)
              (let ((start (copy-marker (point)))
                    end)
                (insert "[サムネイル取得中...]")
                ;; type t だと後続挿入を飲み込み delete-region が壊れるため type nil
                (setq end (copy-marker (point)))
                (insert "\n")
                (url-retrieve
                 (format "https://i.ytimg.com/vi/%s/mqdefault.jpg" id)
                 #'my/youtube-browse--thumbnail-callback
                 (list target generation start end) t t)))
            (insert-text-button
             text
             'action (lambda (_button) (browse-url url))
             'follow-link t
             'help-echo url)
            (insert "\n\n"))))
      t)))

(defun my/youtube-browse--consume-line (process line)
  "Parse one JSON LINE from PROCESS and append it to the result buffer."
  (let ((target (process-get process 'target))
        (generation (process-get process 'generation)))
    (when (and (buffer-live-p target) (not (string-empty-p line)))
      (with-current-buffer target
        (when (and (eq process my/youtube-browse-process)
                   (= generation my/youtube-browse-generation))
          (let ((object (ignore-errors
                          (json-parse-string line :object-type 'alist))))
            (when (and object
                       (my/youtube-browse--insert-entry object generation))
              (process-put process 'count
                           (1+ (process-get process 'count))))))))))

(defun my/youtube-browse--process-filter (process chunk)
  "Accumulate complete JSON lines from PROCESS output CHUNK."
  (let* ((text (concat (process-get process 'pending) chunk))
         (lines (split-string text "\n")))
    (process-put process 'pending (car (last lines)))
    (dolist (line (butlast lines))
      (my/youtube-browse--consume-line
       process (string-trim-right line "\r")))))

(defun my/youtube-browse--more (_button)
  "Fetch the next page from a result-buffer button."
  (my/youtube-browse--load-page))

(defun my/youtube-browse--process-sentinel (process _event)
  "Finish the page represented by PROCESS."
  (when (memq (process-status process) '(exit signal))
    (let ((pending (string-trim-right
                    (or (process-get process 'pending) "") "\r"))
          (target (process-get process 'target))
          (generation (process-get process 'generation)))
      (unless (string-empty-p pending)
        (my/youtube-browse--consume-line process pending))
      (when (buffer-live-p target)
        (with-current-buffer target
          (when (and (eq process my/youtube-browse-process)
                     (= generation my/youtube-browse-generation))
            (setq my/youtube-browse-process nil
                  my/youtube-browse-loading nil)
            (cond
             ((not (zerop (process-exit-status process)))
              (my/youtube-browse--set-tail
               (format "取得に失敗しました (終了コード %d) [再試行]"
                       (process-exit-status process))
               #'my/youtube-browse--more))
             ((zerop (process-get process 'count))
              (my/youtube-browse--set-tail "これ以上結果はありません"))
             (t
              (setq my/youtube-browse-next-start
                    (+ my/youtube-browse-next-start
                       my/youtube-browse-page-size))
              (my/youtube-browse--set-tail
               "[もっと見る]" #'my/youtube-browse--more)))))))))

(defun my/youtube-browse--load-page ()
  "Fetch and append the next page for the current result buffer."
  (unless my/youtube-browse-loading
    (unless (executable-find my/youtube-browse-yt-dlp-program)
      (user-error "yt-dlp が見つかりません: %s"
                  my/youtube-browse-yt-dlp-program))
    (let* ((start my/youtube-browse-next-start)
           (end (+ start my/youtube-browse-page-size -1))
           (command (list my/youtube-browse-yt-dlp-program
                          "-j" "--flat-playlist" "--no-warnings"
                          "--extractor-args" "youtube:skip=authcheck"
                          "--playlist-items" (format "%d-%d" start end)
                          my/youtube-browse-source-url))
           (process-environment
            (append '("PYTHONIOENCODING=utf-8" "PYTHONUTF8=1"
                      "LANG=ja_JP.UTF-8" "LC_ALL=ja_JP.UTF-8")
                    process-environment))
           (coding-system-for-read 'utf-8)
           (coding-system-for-write 'utf-8)
           (target (current-buffer))
           process)
      (setq my/youtube-browse-loading t)
      (my/youtube-browse--set-tail "取得中...")
      (setq process
            (make-process
             :name "youtube-browse"
             :command command
             :connection-type 'pipe
             :coding '(utf-8 . utf-8)
             :noquery t
             :filter #'my/youtube-browse--process-filter
             :sentinel #'my/youtube-browse--process-sentinel))
      (process-put process 'target target)
      (process-put process 'generation my/youtube-browse-generation)
      (process-put process 'pending "")
      (process-put process 'count 0)
      (setq my/youtube-browse-process process))))

(defun my/youtube-browse--reset ()
  "Clear the current buffer and restart its search."
  (when (process-live-p my/youtube-browse-process)
    (let ((process my/youtube-browse-process))
      (setq my/youtube-browse-process nil)
      (delete-process process)))
  (when my/youtube-browse-tail-marker
    (set-marker my/youtube-browse-tail-marker nil))
  (setq my/youtube-browse-next-start 1
        my/youtube-browse-loading nil
        my/youtube-browse-generation (1+ my/youtube-browse-generation))
  (let ((inhibit-read-only t))
    (erase-buffer)
    (insert (propertize (format "YouTube: %s\n\n" my/youtube-browse-query)
                        'face 'bold))
    (setq my/youtube-browse-tail-marker (copy-marker (point) t)))
  (my/youtube-browse--load-page))

(defun my/youtube-browse--revert (&rest _ignore)
  "Repeat the current YouTube search."
  (my/youtube-browse--reset))

(defun my/youtube-browse--kill-process ()
  "Stop the result buffer's yt-dlp process, if any."
  (when (process-live-p my/youtube-browse-process)
    (delete-process my/youtube-browse-process)))

(defun my/youtube-browse-next-entry (&optional n)
  "N 個先の動画（ボタン）へ移動する。末尾では先頭へ回り込む。"
  (interactive "p")
  (forward-button (or n 1) t))

(defun my/youtube-browse-previous-entry (&optional n)
  "N 個前の動画（ボタン）へ移動する。先頭では末尾へ回り込む。"
  (interactive "p")
  (backward-button (or n 1) t))

(defvar-keymap my/youtube-browse-mode-map
  :parent special-mode-map
  "g" #'revert-buffer
  "q" #'quit-window
  "j" #'my/youtube-browse-next-entry
  "k" #'my/youtube-browse-previous-entry
  "n" #'my/youtube-browse-next-entry
  "p" #'my/youtube-browse-previous-entry)

(define-derived-mode my/youtube-browse-mode special-mode "YouTube"
  "Major mode for browsing YouTube search results."
  (setq-local revert-buffer-function #'my/youtube-browse--revert)
  (add-hook 'kill-buffer-hook #'my/youtube-browse--kill-process nil t))

(defun my/youtube-browse--open (query source-url)
  "Open QUERY's result buffer and page through SOURCE-URL."
  (let ((buffer (get-buffer-create (format "*YouTube: %s*" query))))
    (with-current-buffer buffer
      (unless (derived-mode-p 'my/youtube-browse-mode)
        (my/youtube-browse-mode))
      (setq my/youtube-browse-query query
            my/youtube-browse-source-url source-url)
      (my/youtube-browse--reset))
    (pop-to-buffer buffer)))

(defun my/youtube-browse--search-channels (query)
  "Return an alist of channel names and URLs matching QUERY."
  (unless (executable-find my/youtube-browse-yt-dlp-program)
    (user-error "yt-dlp が見つかりません: %s"
                my/youtube-browse-yt-dlp-program))
  (let* ((search-url
          (format "https://www.youtube.com/results?search_query=%s&sp=EgIQAg%%3D%%3D"
                  (url-hexify-string
                   (encode-coding-string query 'utf-8))))
         (command (list my/youtube-browse-yt-dlp-program
                        "-j" "--flat-playlist" "--playlist-end" "15"
                        "--no-warnings" search-url))
         (process-environment
          (append '("PYTHONIOENCODING=utf-8" "PYTHONUTF8=1"
                    "LANG=ja_JP.UTF-8" "LC_ALL=ja_JP.UTF-8")
                  process-environment))
         (coding-system-for-read 'utf-8)
         (coding-system-for-write 'utf-8)
         channels)
    (dolist (line (apply #'process-lines command) (nreverse channels))
      (let* ((object (ignore-errors
                       (json-parse-string line :object-type 'alist)))
             (id (and object (alist-get 'id object)))
             (title (and object (alist-get 'title object))))
        (when (and (stringp id) (string-prefix-p "UC" id)
                   (stringp title))
          (push (cons title (format "https://www.youtube.com/channel/%s" id))
                channels))))))

;;;###autoload
(defun my/youtube-browse-channel ()
  "Choose a channel, then browse videos from that channel."
  (interactive)
  (let ((query (read-string "YouTube チャンネル検索: ")))
    (when (string-empty-p query)
      (user-error "検索語を入力してください"))
    (let ((channels (my/youtube-browse--search-channels query)))
      (when (null channels)
        (user-error "該当するチャンネルがありません"))
      (let* ((channel (completing-read "チャンネル: " channels nil t))
             (url (cdr (assoc channel channels))))
        (my/youtube-browse--open channel (concat url "/videos"))))))

;;;###autoload
(defun my/youtube-browse (&optional channel)
  "Browse YouTube search results, or choose a channel with prefix CHANNEL."
  (interactive "P")
  (if channel
      (call-interactively #'my/youtube-browse-channel)
    (let* ((initial (when (use-region-p)
                      (buffer-substring-no-properties
                       (region-beginning) (region-end))))
           (query (read-string "YouTube 検索: " initial)))
      (when (string-empty-p query)
        (user-error "検索語を入力してください"))
      (my/youtube-browse--open
       query
       (format "https://www.youtube.com/results?search_query=%s"
               (url-hexify-string
                (encode-coding-string query 'utf-8)))))))

(provide 'yt-browse)
;;; yt-browse.el ends here
