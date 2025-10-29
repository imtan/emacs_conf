;;; package --- Summary
;;; Commentary:
;;; Code:

;; ファイルの生成・読み込み（elcでは実行されない）
(eval-when-compile
  (require 'org)
  (org-babel-tangle-file (expand-file-name "early-init.org" user-emacs-directory))
  (org-babel-tangle-file (expand-file-name "config.org" user-emacs-directory))
  (byte-compile-file (expand-file-name "early-init.el" user-emacs-directory))
  (byte-compile-file (expand-file-name "config.el" user-emacs-directory)))

;; すぐバイトコンパイルできるように定義
(defun byte-compile-init-file ()
  (interactive)
  (byte-compile-file (expand-file-name "init.el" user-emacs-directory)))

;; 設定の読み込み
(add-to-list 'load-path (expand-file-name user-emacs-directory))
(require 'config)

(provide 'init)
;;; init.el ends here

(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)

(custom-set-variables ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(warning-suppress-types '((initialization) (comp))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
