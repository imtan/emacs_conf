# Emacs設定 - インストール済みパッケージ一覧

## パッケージ管理
- **straight.el** - メインのパッケージマネージャー
- **quelpa** - 追加のパッケージマネージャー
- **use-package** - パッケージ設定の簡潔化

## Org-mode関連
- **org-roam** - Zettelkasten方式のノート管理システム
  - データベース: `~/Documents/Org/org-roam.db`
  - ディレクトリ: `~/Dropbox/Org`
- **org-roam-ui** - Org-roamのグラフ可視化
- **org-roam-gt** - Org-roam拡張
- **org-roam-bibtex** - 文献管理統合
- **org-roam-books** - 読書ノート管理
- **org-journal** - 日記機能
  - 保存先: `~/Dropbox/Org/journal`
- **org-gcal** - Googleカレンダー同期
- **org-modern** - モダンなOrg-mode UI
- **org-modern-indent** - インデント表示
- **org-bullets** - 見出し装飾
- **org-super-agenda** - 高度なアジェンダビュー

## エディタ機能
### 補完・入力支援
- **company** - 自動補完フレームワーク
- **company-box** - company用ポップアップUI
- **copilot** - GitHub Copilot統合
- **copilot-chat** - GitHub Copilot Chat機能
- **yasnippet** - スニペット管理

### プロジェクト管理
- **projectile** - プロジェクト管理
- **projectile-rails** - Rails専用機能
- **magit** - Git操作インターフェース
- **neotree** - ファイルツリー表示

### 検索・ナビゲーション
- **vertico** - ミニバッファ補完UI
- **vertico-posframe** - ポップアップ表示
- **vertico-multiform** - マルチモード対応
- **vertico-truncate** - 長いパス表示の改善
- **consult** - 検索・ナビゲーション強化
- **consult-spotify** - Spotify統合
- **ivy** - 補完フレームワーク
- **fussy** - ファジー検索

## AI・チャット統合
- **chatgpt-shell** - ChatGPT統合
  - モデル: gpt-4, gpt-4o, gpt-3.5-turbo等
- **claude-code-ide** - Claude Code IDE統合
- **gptel** - GPT統合（別実装）

## 言語サポート
### LSP・開発環境
- **lsp-mode** - Language Server Protocol
- **flycheck** - シンタックスチェック
- **tree-sitter** - 構文解析
- **treesit-auto** - tree-sitter自動設定

### プログラミング言語
- **nim-mode** - Nim言語サポート
- **gdscript-mode** - Godot GDScriptサポート
- **typescript-mode** - TypeScript
- **tide** - TypeScript IDE機能
- **web-mode** - HTML/CSS/JavaScript
- **ruby-mode** + **rubocop** - Ruby
- **markdown-mode** - Markdown編集
- **dockerfile-mode** - Dockerfile
- **yaml-mode** - YAML

## UI・テーマ
- **doom-modeline** - モードライン
- **modus-vivendi** - ダークテーマ（デフォルト）
- **solaire-mode** - バッファ背景の差別化
- **rainbow-delimiters** - 括弧の色分け
- **nyan-mode** - Nyanキャット表示
- **all-the-icons** - アイコン表示
- **nerd-icons-dired** - diredモードアイコン
- **pulsar** - カーソル位置ハイライト
- **lin** - 行ハイライト
- **golden-ratio** - ウィンドウサイズ自動調整
- **olivetti** - 集中執筆モード
- **writeroom-mode** - 集中執筆モード
- **darkroom** - 集中執筆モード

## 日本語入力
- **ddskk** - 日本語入力システム
  - 辞書: `~/.emacs.d/skk-get-jisyo/SKK-JISYO.myjisyo`
- **ddskk-posframe** - SKK候補のポップアップ表示
- **migemo** - ローマ字検索

## ユーティリティ
### 翻訳・検索
- **google-translate** - Google翻訳
- **go-translate** - 翻訳機能（別実装）
- **google-this** - Google検索
- **helm-wikipedia** - Wikipedia検索
- **rg** - ripgrep統合

### その他
- **elfeed** - RSSリーダー
- **elfeed-org** - Org形式のフィード管理
  - フィード設定: `~/Dropbox/Org/feeds.org`
- **dashboard** - スタート画面
- **recentf-ext** - 最近使ったファイル
- **which-key** - キーバインドヘルプ
- **key-chord** - キーコード
- **hydra** - キーバインドメニュー
- **hydra-posframe** - hydraポップアップ表示
- **vundo** - アンドゥツリー可視化
- **toc-org** - 目次生成
- **dired-subtree** - diredサブツリー表示
- **emacs-conflict** - マージ競合解決
- **ligature** - リガチャ表示

### 外部サービス統合
- **exec-path-from-shell** - シェル環境変数の取得
- **eat** - ターミナルエミュレータ
- **web-server** - 内蔵Webサーバー
- **websocket** - WebSocket通信

## キーバインド（主要なもの）

### Org-mode
- `C-c a` - org-agenda
- `C-c c` - org-capture
- `C-c s` - org-schedule
- `C-c j` - org-journal-new-entry
- `C-c i` - 週間ジャーナル統合表示

### Org-roam
- `C-c n l` - org-roam-buffer-toggle
- `C-c n f` - org-roam-node-find
- `C-c n i` - org-roam-node-insert
- `C-c n c` - org-roam-capture
- `C-c n j` - org-roam-dailies-capture-today
- `C-c n p` - ページ番号付きリンク挿入

### エディタ
- `C-c g` - magit-status
- `C-TAB` - copilot補完受け入れ
- `C-x m` - chatgpt-shell
- `C-c u` - vundo (アンドゥツリー)
- `F8` - neotree-toggle

### Claude Code IDE
- `C-c C-'` - claude-code-ide-menu
- `C-c C-c` - claude-code-ide
- `C-c C-r` - claude-code-ide-resume
- `C-c C-s` - claude-code-ide-stop

### ナビゲーション
- `C-c <left/down/up/right>` - ウィンドウ間移動

### その他
- `C-c ,` - init.elを開く
- `C-c w w` - 作業ディレクトリを開く
- `C-c w g` - ゲームディレクトリを開く
- `C-c d` - Google翻訳
- `C-\\` - SKK日本語入力

## 注意事項
- APIキーがハードコードされています（要セキュリティ見直し）:
  - Linear API (init.el:18)
  - OpenAI API (環境変数から取得)
  - Google Calendar認証情報 (init.el:739-741)
- 多数の同期競合ファイルが存在（Dropbox同期の問題の可能性）
- projectile.cache が5.4MBと大きい

## ディレクトリ構造
```
.emacs.d/
├── init.el                    # メイン設定ファイル
├── init-linux.el              # Linux専用設定
├── init-osx.el                # macOS専用設定
├── straight/                  # パッケージソース
├── elpa/                      # 追加パッケージ
├── ddskk/                     # 日本語入力辞書
├── org-gcal/                  # Googleカレンダー連携
├── chatgpt/                   # ChatGPT関連
├── server/                    # Emacsサーバー
├── org-persist/               # Org永続化データ
└── tree-sitter/               # tree-sitterグラマー
```

## 外部データディレクトリ
- Orgファイル: `~/Dropbox/Org/`
- ジャーナル: `~/Dropbox/Org/journal/`
- タスク: `~/Dropbox/Org/capture/tasks.org`
- Org-roam DB: `~/Documents/Org/org-roam.db`
- 作業ディレクトリ: `~/Documents/Repository/Works`
- ゲーム開発: `~/WeaponMakingGame`
