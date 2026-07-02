# Emacs設定

このディレクトリには、Emacsのパーソナル設定が含まれています。

## ファイル構成

- `init.org` - Org-modeで管理されたメイン設定ファイル（リテラートプログラミング）
- `init.el` - init.orgから生成される実際の設定ファイル
- `init-linux.el` - Linux固有の設定
- `init-osx.el` - macOS固有の設定
- `.gitignore` - Gitで管理しないファイルの指定
- `PACKAGES.md` - インストール済みパッケージ一覧
- `SECURITY_AUDIT.md` - セキュリティ監査レポート

## 使い方

### 初回セットアップ

1. **認証情報の設定**

APIキーは環境変数または `~/.authinfo.gpg` で管理します:

```bash
# 環境変数で設定する場合
export LINEAR_API_KEY="your-linear-api-key"
export GCAL_CLIENT_ID="your-google-client-id"
export GCAL_CLIENT_SECRET="your-google-client-secret"
export OPENAI_API_KEY="your-openai-api-key"
```

または `~/.authinfo.gpg` (GPG暗号化) で管理:

```
machine api.linear.app login user password your-linear-api-key
machine gcal-client-id login user password your-google-client-id
machine gcal-client-secret login user password your-google-client-secret
machine api.openai.com login user password your-openai-api-key
```

2. **Emacsを起動**

Emacsを起動すると、straight.elが自動的にパッケージをインストールします。

### init.orgから設定を編集

設定は `init.org` で管理されています。Org-modeのリテラートプログラミング形式で記述されており、各セクションごとに整理されています。

**自動生成:**
- `init.org` を保存してEmacsを再起動すると、自動的に `init.el` が生成されます
- `early-init.el` が `init.org` の変更を検知して自動的にtangleします

**手動生成:**
1. `C-c ,` で `init.org` を開く
2. `init.org` を編集
3. `C-c C-v t` (org-babel-tangle) で `init.el` に変換
4. `M-x eval-buffer` または Emacs再起動で反映

**メリット:**
- コードブロックごとに整理された読みやすい設定
- 目次から各セクションへジャンプ可能
- コメントや説明を自然に記述できる
- `:tangle no` で特定のブロックを除外可能

## 主な機能

### Org-mode
- **Org-roam**: Zettelkasten形式のノート管理
- **Org-journal**: 日記機能
- **Org-capture**: タスクキャプチャ
- **Org-gcal**: Googleカレンダー同期
- **Org-modern**: モダンなUI

### AI統合
- **ChatGPT Shell**: ChatGPT統合 (`C-x m`)
- **GitHub Copilot**: コード補完 (`C-TAB`)
- **Claude Code IDE**: Claude統合 (`C-c C-c`)

### エディタ機能
- **Magit**: Git操作 (`C-c g`)
- **Projectile**: プロジェクト管理 (`C-c p`)
- **LSP Mode**: 言語サーバー統合
- **Flycheck**: シンタックスチェック

## 主なキーバインド

| キー | 機能 |
|------|------|
| `C-c ,` | init.elを開く |
| `C-c a` | Org-agenda |
| `C-c c` | Org-capture |
| `C-c g` | Magit status |
| `C-c n f` | Org-roam node find |
| `C-c n i` | Org-roam node insert |
| `C-x m` | ChatGPT shell |
| `C-TAB` | Copilot補完 |
| `F8` | Neotreeトグル |
| `C-\\` | SKK日本語入力 |

詳細は `PACKAGES.md` を参照してください。

## Gitで管理

### 初回コミット

```bash
cd ~/.emacs.d
git init
git add init.org early-init.el init-linux.el init-osx.el .gitignore README.md PACKAGES.md
git commit -m "Initial commit: Emacs configuration

- init.org: Main configuration in literate programming style
- early-init.el: Auto-tangle init.org to init.el
- Security improvements: API keys moved to environment variables"
```

### リモートリポジトリへのプッシュ

```bash
git remote add origin https://github.com/yourusername/emacs.d.git
git push -u origin main
```

**注意**:
- `init.el` は自動生成されるため、Gitで管理しません（.gitignoreに含まれています）
- `.gitignore` により、機密情報を含むファイルは自動的に除外されます
- プッシュ前に古いAPIキーを必ず無効化してください

## セキュリティ

- APIキーは環境変数または `~/.authinfo.gpg` で管理
- 機密ファイルは `.gitignore` で除外
- 詳細は `SECURITY_AUDIT.md` を参照

## トラブルシューティング

### パッケージのインストールエラー

```elisp
M-x straight-check-all
M-x straight-rebuild-all
```

### 設定の再読み込み

```elisp
M-x eval-buffer
```

または Emacs再起動

## ディレクトリ構造

```
.emacs.d/
├── init.org              # メイン設定（Org-mode）
├── init.el               # 生成された設定ファイル
├── init-linux.el         # Linux固有設定
├── init-osx.el           # macOS固有設定
├── .gitignore            # Git除外設定
├── README.md             # このファイル
├── PACKAGES.md           # パッケージ一覧
├── SECURITY_AUDIT.md     # セキュリティ監査
├── straight/             # パッケージ（除外）
├── elpa/                 # 追加パッケージ（除外）
└── sync-conflicts-backup/  # 同期競合バックアップ
```

## ライセンス

個人利用のため、ライセンスは設定していません。

## 参考リンク

- [Emacs公式](https://www.gnu.org/software/emacs/)
- [Org-mode](https://orgmode.org/)
- [Straight.el](https://github.com/raxod502/straight.el)
- [Org-roam](https://www.orgroam.com/)
