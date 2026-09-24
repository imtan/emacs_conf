;;; neomacs.el --- NEO Emacs (neomacs) 向け回避コード -*- lexical-binding: t -*-

(require 'cl-lib)

;; neomacs 0.0.18 回避: define-key が keymap 型 autoload (<f2> = 2C-command) を
;; プレフィックスとして解決できず hydra-zoom の定義で止まるため、先に外しておく
(global-unset-key (kbd "<f2>"))

;; neomacs 0.0.18 回避: font-info が常に nil を返し、default-font-height/width が
;; (aref nil 3) で落ちる（corfu・posframe 系が全滅する）。フレームの文字サイズから合成する
;; ponytail: ascent/descent は概算。上流で font-info が実装されたら削除
(defun my/neomacs-font-info-fallback (f name &optional frame)
  (or (funcall f name frame)
      (let ((h (frame-char-height frame)) (w (frame-char-width frame)))
        (vector name name h h 0 0 (- h (/ h 5)) w (- h (/ h 5)) (/ h 5) w w nil nil))))
(advice-add 'font-info :around #'my/neomacs-font-info-fallback)

;; neomacs 0.0.18 回避: posn-at-point が常に nil を返す。動く pos-visible-in-window-p から合成する
;; ponytail: X はフリンジ/行番号幅ぶんずれうる。上流で posn-at-point が実装されたら削除
(defun my/neomacs-posn-at-point-fallback (f &optional pos window)
  (or (funcall f pos window)
      (let* ((window (or window (selected-window)))
             (pos (or pos (window-point window)))
             (xy (pos-visible-in-window-p pos window t)))
        (when xy
          (list window pos (cons (car xy) (cadr xy)) 0 nil pos
                (cons (with-current-buffer (window-buffer window)
                        (save-excursion (goto-char pos) (current-column)))
                      (count-screen-lines (window-start window) pos nil window))
                nil (cons 0 0) (cons (frame-char-width) (frame-char-height)))))))
(advice-add 'posn-at-point :around #'my/neomacs-posn-at-point-fallback)

;; neomacs 0.0.18 回避: Command は Super 固定で、mac-command-modifier 相当の設定が無い
;; （Option=Meta は Rust 側でハードコード）。Emacs.app と同じ Command=Meta にするため
;; s-<文字> / C-s-<文字> を M- / C-M- に読み替える
;; ponytail: 印字可能 ASCII と backspace のみ。矢印や F キーが要るなら同じ形で足す
(dolist (c (number-sequence 32 126))
  (define-key key-translation-map (vector (event-convert-list (list 'super c)))
              (vector (event-convert-list (list 'meta c))))
  (define-key key-translation-map (vector (event-convert-list (list 'control 'super c)))
              (vector (event-convert-list (list 'control 'meta c)))))
(define-key key-translation-map (kbd "s-<backspace>") (kbd "M-<backspace>"))

;; neomacs 0.0.18 回避: format-time-string が system-time-locale を無視して常に英語を返す。
;; org-journal が既存の日本語見出し「日曜日, 20 9月 2026」を見つけられず英語の見出しを重複作成し、
;; org のタイムスタンプ曜日も <... Sun> になって本家と食い違う。日本語ロケール時だけ曜日/月/午前午後を差し替える
;; ponytail: 修飾なしの %A %a %B %b %p のみ（%^a や %-B は非対応）。上流で直ったら削除
(defun my/neomacs-format-time-string-ja (f format &optional time zone)
  (if (not (string-prefix-p "ja" (or system-time-locale "")))
      (funcall f format time zone)
    (let* ((d (decode-time time zone))
           (dow (nth 6 d)) (mon (nth 4 d)) (hour (nth 2 d))
           (day (aref ["日" "月" "火" "水" "木" "金" "土"] dow)))
      (funcall f (replace-regexp-in-string
                  "%[%AaBbp]"
                  (lambda (m)
                    (pcase m
                      ("%A" (concat day "曜日")) ("%a" day)
                      ("%B" (format "%d月" mon)) ("%b" (format "%2d月" mon))
                      ("%p" (if (< hour 12) "午前" "午後"))
                      (_ m)))
                  format t t)
               time zone))))
(advice-add 'format-time-string :around #'my/neomacs-format-time-string-ja)

;; neomacs 0.0.18 回避: 上方向の vertical-motion が、着地先の行頭が不可視 / display プロパティ付き
;; （org のインライン画像やリンクの [[ 等）だと 0 を返して1行も動かない。
;; 失敗したときだけ1行ずつ移動し直す。1行の移動も失敗したら論理行で戻る
;; ponytail: 失敗時のみ O(行数)。折り返し行は論理行扱いになる。上流で直ったら削除
(defun my/neomacs-vertical-motion-fallback (f lines &optional window cur-only)
  (let ((r (funcall f lines window cur-only)))
    (if (or (not (integerp lines)) (>= lines 0) (/= r 0)
            (= (line-beginning-position) (point-min)))
        r
      (let ((moved 0) (want (- lines)))
        (while (and (< moved want) (not (bobp)))
          (let ((p (point)))
            (when (= 0 (funcall f -1 window cur-only))
              (forward-line -1)
              (while (and (not (bobp)) (invisible-p (point))) (forward-line -1)))
            (if (= (point) p) (setq moved want) (setq moved (1+ moved)))))
        (- moved)))))
(advice-add 'vertical-motion :around #'my/neomacs-vertical-motion-fallback)

;; neomacs 0.0.18 回避: recenter は Rust 実装で上の advice を通らず、同じ不具合で C-l が効かない
;; （日報のように画像行より下で中央寄せ/下端寄せすると window-start が動かない）。
;; 本体を呼んだ後、あるべき開始位置を上の vertical-motion で計算し、ずれていれば補正する
;; ponytail: scroll-margin は考慮しない
(defun my/neomacs-recenter-fix (f &optional arg redisplay)
  (funcall f arg redisplay)
  (when (eq (window-buffer) (current-buffer))
    (let* ((h (window-body-height))
           (n (cond ((or (null arg) (consp arg)) (/ h 2))
                    ((>= (prefix-numeric-value arg) 0) (prefix-numeric-value arg))
                    (t (max 0 (+ h (prefix-numeric-value arg))))))
           (want (save-excursion (vertical-motion (- n)) (point))))
      (unless (= want (window-start)) (set-window-start nil want)))))
(advice-add 'recenter :around #'my/neomacs-recenter-fix)

;; neomacs 0.0.18 回避: nostr.el は鍵の GPG 復号を make-thread のワーカーで走らせるが、neomacs では
;; パスフレーズ入力後にスレッドが戻らず nostr-open が「Deriving configured account pubkey.」で止まる。
;; その呼び出しの間だけ make-thread をタイマー実行に差し替え、メインスレッドで復号する
;; ponytail: 復号中は一瞬ブロックする。上流で Lisp スレッドが直ったら削除
(defun my/neomacs-nostr-no-thread (f &rest args)
  (cl-letf (((symbol-function 'make-thread)
             (lambda (fn &optional _name) (run-at-time 0 nil fn))))
    (apply f args)))
(advice-add 'nostr-setup-derive-pubkey-async :around #'my/neomacs-nostr-no-thread)

(defun my/neomacs-after-config ()
  "config.el 読み込み後に neomacs 向けの表示・補完設定を適用する。"
  ;; neomacs 0.0.18 回避: config.el が C-v/M-v を pixel-scroll-interpolate-down/up に差し替えているが、
  ;; neomacs ではエラーも出さず何も起きない（ピクセル単位の vscroll 補間が効かない）。
  ;; 標準の scroll-up/down-command に戻す。滑らかさは neomacs 自前の GPU スクロールアニメに任せる
  (keymap-global-unset "<remap> <scroll-up-command>" t)
  (keymap-global-unset "<remap> <scroll-down-command>" t)

  ;; neomacs 0.0.18 回避: Lisp 側の表示計算が画像の高さを無視する（line-pixel-height が画像行で 1 を返す等）ため、
  ;; 画像のあるバッファで C-v が「End of buffer」になったり画像を一気に飛び越えたりする。
  ;; 描画側はピクセル単位の vscroll に対応しているので、行の高さを自前で数えて window-start と vscroll を決める。
  ;; 画像の無いバッファは標準コマンドのまま
  ;; ponytail: 行の高さ = 画像の高さ or 文字の高さ。折り返し行・拡大見出しは 1 行ぶん扱い。上流で直ったら削除
  (defun my/neomacs--line-image-height ()
    "現在行に画像があればその高さ(px)、無ければ nil."
    (let ((bol (line-beginning-position)) (eol (line-end-position)) h)
      (dolist (o (overlays-in bol (1+ eol)))
	(let ((d (overlay-get o 'display)))
          (when (eq (car-safe d) 'image)
            (setq h (max (or h 0) (ceiling (cdr (image-size d t))))))))
      (let ((d (get-text-property bol 'display)))
	(when (eq (car-safe d) 'image)
          (setq h (max (or h 0) (ceiling (cdr (image-size d t)))))))
      h))

  (defun my/neomacs--line-px ()
    "現在行の表示高さ(px). 折りたたまれて見えない行は 0."
    (let ((bol (line-beginning-position)))
      (cond ((my/neomacs--line-image-height))
            ((and (> bol (point-min)) (invisible-p (1- bol))) 0)
            (t (frame-char-height)))))

  (defun my/neomacs--buffer-has-images-p ()
    (seq-some (lambda (o) (eq (car-safe (overlay-get o 'display)) 'image))
              (overlays-in (point-min) (point-max))))

  (defun my/neomacs--scroll-pixels (delta &optional exact)
    "表示を DELTA px だけ下へ（負なら上へ）進める. 背の高い行（画像）の途中でも止まる.
EXACT が non-nil なら普通の行も行頭に揃えず、ピクセル単位の位置をそのまま使う（ホイール用）."
    (let* ((ch (frame-char-height))
           (win-h (window-body-height nil t))
           (pos (window-start))
           (off (+ (window-vscroll nil t) delta))) ; pos の行頭から測った、新しい表示上端までの px
      (save-excursion
	(goto-char pos)
	(if (>= off 0)
            (let (h)
              (while (and (>= off (setq h (my/neomacs--line-px)))
                          (save-excursion (= 0 (forward-line 1)) (not (eobp))))
		(setq off (- off h))
		(forward-line 1))
              ;; 最終行より先へは進めない
              (setq off (min off (max 0 (- h 1)))))
          (while (and (< off 0) (not (bobp)))
            (forward-line -1)
            (setq off (+ off (my/neomacs--line-px))))
          (setq off (max off 0)))
	(setq pos (line-beginning-position))
	;; 普通の高さの行は行頭に揃える。途中で止めるのは背の高い行だけ
	(when (and (not exact) (<= (my/neomacs--line-px) (* 3 ch))) (setq off 0)))
      (set-window-start nil pos)
      (set-window-vscroll nil off t)
      ;; カーソルを表示範囲に収める
      (when (< (point) pos) (goto-char pos))
      (let ((y (- off)) (last pos))
	(save-excursion
          (goto-char pos)
          (while (and (not (eobp)) (<= (+ y (my/neomacs--line-px)) win-h))
            (setq y (+ y (my/neomacs--line-px)) last (point))
            (forward-line 1)))
	(when (> (point) (save-excursion (goto-char last) (line-end-position)))
          (goto-char last)))))

  (defun my/neomacs--page-px ()
    (- (window-body-height nil t) (* next-screen-context-lines (frame-char-height))))

  (defun my/neomacs-scroll-up (&optional arg)
    "画像の高さを考慮した `scroll-up-command'."
    (interactive "^P")
    (if (or arg (not (my/neomacs--buffer-has-images-p)))
	(scroll-up-command arg)
      ;; GNU Emacs と同じく、末尾がすでに見えているならそれ以上進めない
      (let ((y (- (window-vscroll nil t))) (win-h (window-body-height nil t)))
	(save-excursion
          (goto-char (window-start))
          (while (and (not (eobp)) (<= y win-h))
            (setq y (+ y (my/neomacs--line-px)))
            (forward-line 1)))
	(when (<= y win-h) (signal 'end-of-buffer nil)))
      (my/neomacs--scroll-pixels (my/neomacs--page-px))))

  (defun my/neomacs-scroll-down (&optional arg)
    "画像の高さを考慮した `scroll-down-command'."
    (interactive "^P")
    (if (or arg (not (my/neomacs--buffer-has-images-p)))
	(scroll-down-command arg)
      (let ((s (window-start)) (v (window-vscroll nil t)))
	(my/neomacs--scroll-pixels (- (my/neomacs--page-px)))
	(when (and (= s (window-start)) (= v (window-vscroll nil t)))
          (signal 'beginning-of-buffer nil)))))

  ;; ホイール/トラックパッド: pixel-scroll-precision は画像の高さを知らない計算 API に頼るため、
  ;; 画像のあるバッファで上端まで戻ると末尾へ飛ばされる。同じピクセル送りに移動量を渡す。
  ;; 移動量の符号は pixel-scroll-precision と同じ扱い（イベントの dy が負 = 末尾方向）
  (defun my/neomacs-wheel-scroll (event)
    "画像のあるバッファでは自前のピクセル送り、それ以外は `pixel-scroll-precision'."
    (interactive "e")
    (let* ((window (mwheel-event-window event))
           (dy (cdr-safe (nth 4 event)))
           ;; neomacs 0.0.18 の実機イベントは (wheel-up POSN) だけでピクセル移動量を持たない。
           ;; その場合は 1 イベント = 2 行ぶんの固定量で送る（wheel-up = 先頭方向）
           (step (* 2 (frame-char-height)))
           (delta (cond ((numberp dy) (- (round dy)))
			((eq (event-basic-type event) 'wheel-up) (- step))
			(t step))))
      (if (not (with-current-buffer (window-buffer window) (my/neomacs--buffer-has-images-p)))
          (pixel-scroll-precision event)
	(with-selected-window window
          (my/neomacs--scroll-pixels delta t)))))
  (keymap-global-set "<remap> <pixel-scroll-precision>" #'my/neomacs-wheel-scroll)

  (keymap-global-set "<remap> <scroll-up-command>" #'my/neomacs-scroll-up)
  (keymap-global-set "<remap> <scroll-down-command>" #'my/neomacs-scroll-down)

  ;; neomacs お試し用: フレームシェーダーのライブコーディング
  ;; .glsl/.wgsl バッファで C-c C-c = 画面全体に適用、C-c C-k = 解除、C-c C-o = 絵だけ/合成 の切替
  ;; GLSL バッファには「絵だけ」を素の Shadertoy 形式で書く。エディタ画面との合成は下のラッパーが
  ;; 外から足すので、バッファを undo/編集しても切替の仕組みは消えない
  (defvar my/neomacs-shader-only 0.0
    "1.0 ならシェーダーの絵だけ、0.0 ならエディタ画面と合成。")
  (defvar my/neomacs-shader-strength 0.12
    "合成時に背景へ足す絵の濃さ。(neomacs-frame-shader-set-uniform \\='strength 0.3) で即変更可。")
  (defconst my/neomacs-shader-glsl-wrapper "
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 pic; userImage(pic, fragCoord);
    vec2 uv = fragCoord / iResolution.xy;
    vec4 src = texture(iChannel0, vec2(uv.x, 1.0 - uv.y));
    float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
    float mask = 1.0 - smoothstep(0.02, 0.15, lum);
    fragColor = mix(vec4(src.rgb + pic.rgb * u_strength() * mask, 1.0), vec4(pic.rgb, 1.0), u_only());
}
" "ユーザーの mainImage を userImage に改名した後ろへ足す合成用 mainImage。")
  (defun my/neomacs-shader-apply ()
    "現在のバッファをフレームシェーダーとして画面全体に適用する。"
    (interactive)
    (let* ((glsl (or (string-suffix-p ".glsl" (or buffer-file-name ""))
                     (save-excursion (goto-char (point-min))
                                     (looking-at-p "// language: glsl"))))
           (src (buffer-string))
           ;; ponytail: 自前で iChannel0 を読むポストシェーダーと WGSL はラップせず素通し（C-c C-o は効かない）
           (wrap (and glsl (not (string-match-p "iChannel0" src)))))
      (when wrap
	(setq src (concat (replace-regexp-in-string "\\_<mainImage\\_>" "userImage" src t t)
                          my/neomacs-shader-glsl-wrapper)))
      (condition-case e
          (progn (neomacs-frame-shader src (if glsl 'glsl 'wgsl)
                                       `((only . ,my/neomacs-shader-only)
					 (strength . ,my/neomacs-shader-strength)))
		 (message "shader applied (%s%s)" (if glsl "glsl" "wgsl") (if wrap ", 合成つき" ", 素通し")))
	(error (message "shader error: %s" (error-message-string e))))))
  (defun my/neomacs-shader-toggle-only ()
    "再コンパイルなしで「シェーダーのみ」と「エディタと合成」を切り替える。"
    (interactive)
    (setq my/neomacs-shader-only (if (> my/neomacs-shader-only 0.5) 0.0 1.0))
    (condition-case e
	(progn (neomacs-frame-shader-set-uniform 'only my/neomacs-shader-only)
               (message "shader only: %s" (if (> my/neomacs-shader-only 0.5) "ON (C-c C-o で戻る)" "OFF")))
      (error (message "shader error: %s" (error-message-string e)))))
  (define-minor-mode my/neomacs-shader-mode
    "フレームシェーダーをその場で試すためのマイナーモード。"
    :lighter " Shader"
    :keymap (let ((m (make-sparse-keymap)))
              (define-key m (kbd "C-c C-c") #'my/neomacs-shader-apply)
              (define-key m (kbd "C-c C-k") (lambda () (interactive) (neomacs-frame-shader nil) (message "shader off")))
              (define-key m (kbd "C-c C-o") #'my/neomacs-shader-toggle-only)
              m))
  (add-to-list 'auto-mode-alist '("\\.\\(glsl\\|wgsl\\)\\'" . (lambda () (prog-mode) (my/neomacs-shader-mode 1))))

  ;; neomacs お試し用: corfu（本家 config.org には未導入。気に入ったら本家へ移す）
  ;; :straight の展開は、config.el が use-package 連携を読み込んだ後に行う
  (eval '(use-package corfu
           :straight t
           :custom (corfu-auto t) (corfu-auto-delay 0.1) (corfu-auto-prefix 2)
           :init (global-corfu-mode 1))))

(add-hook 'after-init-hook #'my/neomacs-after-config)

(provide 'neomacs)
;;; neomacs.el ends here
