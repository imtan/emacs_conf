# Emacs設定

Org-modeのリテラートプログラミングで管理したEmacs設定です。

## ファイル構成

| ファイル | 役割 | Git管理 |
|---|---|---|
| `config.org` | メイン設定（編集はここで行う） | ○ |
| `early-init.org` | early-init設定（straightブートストラップ等） | ○ |
| `init.el` | 起動ブートストラップ。`.org`が新しいときだけtangleして`config.el`等を生成 | ○ |
| `config.el` / `early-init.el` | tangleで自動生成される実体 | ×（.gitignore） |
| `custom.el` | Customizeの書き込み先（個人データを含むため分離） | ×（.gitignore） |
| `consult-yt.el` | yt-dlpによるYouTube検索（`C-c y`） | ○ |
| `templates/journal-daily.org` | org-journalの日次テンプレート | ○ |
| `windows/paste_image.ps1` | Windowsでクリップボード画像を保存するスクリプト | ○ |
| `skk-get-jisyo/` | DDSKK用辞書 | ○ |

## セットアップ

1. このリポジトリを `~/.emacs.d` にclone
2. Emacsを起動すると、init.elが`.org`をtangleし、straight.elがパッケージを自動インストールする
3. APIキー（Gemini執筆支援を使う場合）は `~/.authinfo` または環境変数で設定:

```
# ~/.authinfo（または ~/.authinfo.gpg）
machine generativelanguage.googleapis.com login apikey password your-gemini-api-key
```

```bash
# または環境変数
export GEMINI_API_KEY="your-gemini-api-key"
```

秘密情報をこのリポジトリ内のファイルに書かないこと（.gitignoreで機密系パターンは除外済み）。

## 設定の編集フロー

1. `C-c ,` で `config.org` を開いて編集・保存
2. Emacsを再起動すると、`config.org` が `config.el` より新しい場合のみ自動でtangleされて反映される
   （すぐ反映したい場合は `C-c C-v t` で手動tangle → `M-x eval-buffer`）

`.el` を直接編集しないこと（tangleで上書きされる）。

## 主な機能

- **Org-mode まわり**: org-roam（Zettelkasten）、org-journal（日報＋日次テンプレート）、org-capture（タスク／ISBN自動取得の蔵書キャプチャ）、org-super-agenda、org-ql、calfw（月間カレンダー）、org-modern
- **蔵書管理**: openBD / OpenLibrary / NDLサーチから書誌を自動取得、`C-c b` のBooks Viewerで一覧・絞り込み
- **画像**: クリップボード画像貼り付け（Windows/macOS対応）、Eagleライブラリからのプレビュー付き画像挿入
- **日本語入力・検索**: DDSKK、migemo（ローマ字で日本語をインクリメンタル検索）
- **補完・検索UI**: vertico + orderless + consult
- **AI統合**: Claude Code（vterm内で起動・操作）、Gemini執筆支援（gptelで翻訳・校正・要約・下書き生成）
- **開発**: magit、projectile、lsp-mode、flycheck、GDScript（Godot）、Ruby/Rails

## 主なキーバインド

| キー | 機能 |
|------|------|
| `C-c ,` | config.orgを開く |
| `C-c a` | org-agenda |
| `C-c c` | org-capture（`B`=ISBN自動取得の蔵書キャプチャ） |
| `C-c j` | org-journal 日報 |
| `C-c b` | Books Viewer（蔵書一覧） |
| `C-c n f` / `C-c n i` | org-roam ノード検索／挿入 |
| `C-c n s` | ~/Dropbox/Org 全文検索（ripgrep） |
| `C-x g` / `C-c g` | magit-status / magit-file-dispatch |
| `C-c p` | projectile |
| `C-M-y` | クリップボード画像を貼り付け（org-mode） |
| `C-M-e` / `C-c e` | Eagleから画像挿入：検索／フォルダ選択（org-mode） |
| `C-c C c` ほか | Claude Code（`t`=トグル `n`=新規 `r`=リージョン送信 `f`=ファイル送信） |
| `C-c G ...` | Gemini執筆支援（翻訳・校正・要約・下書き） |
| `C-c y` | YouTube検索（yt-dlp） |
| `C-c v` | PowerShell経由でクリップボード貼り付け |
| `C-\` | SKK日本語入力 |
| `M-g l` | consult-line（migemo対応） |
| `<f2>` | ズームhydra |

## トラブルシューティング

```
M-x straight-check-all      ; パッケージの整合性チェック
M-x straight-rebuild-all    ; 全パッケージ再ビルド
M-x straight-pull-all       ; 全パッケージ更新
```

Emacs外でパッケージソースを編集した場合は `M-x straight-rebuild-package` で手動再ビルドする（起動高速化のため全スキャンは無効化してある）。

## ライセンス

個人利用のため、ライセンスは設定していません。
