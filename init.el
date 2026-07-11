;;; package --- Summary
;;; Commentary:
;;; Code:

;; config.org / early-init.org を起動時に tangle して .el を生成する。
;; .el が無い、または .org の方が新しいときだけ実行するので、
;; 新規マシン(Windows等)でも config.org から確実に生成され、編集も即反映される。
(require 'org)

(defun my/tangle-if-needed (base)
  "BASE.org を、対応する BASE.el が無い/古いときだけ tangle する。"
  (let ((org (expand-file-name (concat base ".org") user-emacs-directory))
        (el  (expand-file-name (concat base ".el")  user-emacs-directory)))
    (when (and (file-exists-p org)
               (or (not (file-exists-p el))
                   (file-newer-than-file-p org el)))
      (org-babel-tangle-file org el))))

(my/tangle-if-needed "early-init")
(my/tangle-if-needed "config")

;; 新規マシン(Windows等)では early-init.el が存在せず early-init 段階の
;; straight ブートストラップが走らない。その場合はこの起動内で読み込んで、
;; 初回1回で config まで読めるようにする。
(unless (featurep 'straight)
  (let ((ei (expand-file-name "early-init.el" user-emacs-directory)))
    (when (file-exists-p ei)
      (load ei nil 'nomessage))))

;; 古い .elc が残っていても、新しい .el を優先して読み込む
(setq load-prefer-newer t)

;; Customizeの書き込み先を分離する。init.elはgit管理されているため、
;; ここに書かせると個人データ（ローカルパス等）が公開リポジトリに混入する。
;; org-journalのagenda統合も起動のたびにここへ書き込んでいた。
;; config.el 読込中の customize 保存も拾えるよう、config より先に設定する
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

;; すぐバイトコンパイルできるように定義
(defun byte-compile-init-file ()
  "Byte-compile init.el file."
  (interactive)
  (byte-compile-file (expand-file-name "init.el" user-emacs-directory)))

(defun byte-compile-config-files ()
  "Byte-compile early-init.el and config.el files after packages are loaded."
  (interactive)
  (byte-compile-file (expand-file-name "early-init.el" user-emacs-directory))
  (byte-compile-file (expand-file-name "config.el" user-emacs-directory)))

;; 設定の読み込み
;; ~/.emacs.d を load-path に入れると、直下の接続履歴ファイル tramp 等が
;; 同名ライブラリと誤認される（TRAMPロード時にgitが走る原因になった）ため、
;; load-path には追加せず config.el を直接 load する
(load (expand-file-name "config.el" user-emacs-directory) nil 'nomessage)

(provide 'init)
;;; init.el ends here

(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)

(when (file-exists-p custom-file)
  (load custom-file nil 'nomessage))
