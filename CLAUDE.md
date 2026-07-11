# CLAUDE.md
日本語で必ず返答してください

<?xml version="1.0" encoding="UTF-8"?>
<claude-project-guidelines>
<!-- RFC 2119準拠のキーワード定義 -->
<keyword-definitions>
<keyword level="MUST" description="絶対的要求事項（しなければならない）"/>
<keyword level="MUST_NOT" description="絶対的禁止事項（してはならない）"/>
<keyword level="SHOULD" description="強い推奨事項（するべきである）"/>
<keyword level="SHOULD_NOT" description="強い非推奨事項（するべきではない）"/>
<keyword level="MAY" description="任意事項（してもよい）"/>
</keyword-definitions>

<!-- AI運用原則：決定権は常にユーザーにある -->
<ai-operation-principles>
<principle id="1" level="MUST">破壊的・不可逆な操作（ファイル削除、git履歴の書き換え、push、公開に関わる変更）は実行前にユーザーの確認を取る</principle>
<principle id="2" level="MUST_NOT">要求されたスコープの外に出ない。仕様の解釈に迷ったら勝手に決めずに質問する</principle>
<principle id="3" level="MAY">読み取り・分析・可逆な編集は、何をするかを一言述べた上で自律的に実行してよい</principle>
<principle id="4" level="MUST_NOT">ユーザーの指示・提案の意図を勝手に「最適化」したり解釈変更したりしない</principle>
</ai-operation-principles>

<!-- ファイル読み込み原則 -->
<file-reading-principles>
<principle id="1" level="MUST">
<description>ファイルを読み込む場合は、一気に読み込む</description>
<reason>部分的な読み込みは文脈を見失い、ミスを招く可能性がある</reason>
</principle>
</file-reading-principles>

<!-- プロジェクト構成と編集ルール -->
<project-structure>
<overview>Org-modeのリテラートプログラミングで管理したEmacs設定。GitHubで公開している（PUBLICリポジトリ）。</overview>
<rule id="struct-1" level="MUST">設定の編集は config.org / early-init.org に対して行う</rule>
<rule id="struct-2" level="MUST_NOT">config.el / early-init.el を直接編集しない（tangle生成物。.orgの方が新しいと起動時に上書き再生成される）</rule>
<rule id="struct-3" level="MAY">init.el はtangleのブートストラップであり、直接編集してよい</rule>
<rule id="struct-4" level="MUST_NOT">custom.el に設定を手で書かない（Customize専用の書き込み先。.gitignore済み）</rule>
<note>~/.emacs.d は load-path に追加しない方針（直下の接続履歴ファイル tramp 等が同名ライブラリと誤認されるため）。直下の .el（consult-yt.el等）は config.org から load で明示的に読み込む。</note>
</project-structure>

<!-- 公開リポジトリの注意 -->
<public-repo-rules>
<rule id="pub-1" level="MUST_NOT">APIキー等の秘密情報をリポジトリ内のファイルに書かない。~/.authinfo(.gpg) または環境変数で管理する</rule>
<rule id="pub-2" level="MUST_NOT">ユーザー名入りの絶対パス（C:/Users/... や /Users/...）をコミットしない。~/ 形式＋expand-file-name、または executable-find を使う</rule>
<rule id="pub-3" level="MUST">実行中のEmacsが init.el 末尾に custom-set-variables を追記することがある。この追記はコミットに含めない（Emacs再起動後に git checkout -- init.el で掃除する）</rule>
<rule id="pub-4" level="SHOULD_NOT">skk-get-jisyo/ は .gitignore に記載があるが意図的に追跡している（ユーザーの判断）。追跡解除を提案・実行しない</rule>
</public-repo-rules>

<!-- コミット規約 -->
<commit-conventions>
<rule id="commit-1" level="MUST">件名は英語・命令形（72字以内）。本文は What/Why/Impact を日本語で書く（/commitスキル準拠）</rule>
<rule id="commit-2" level="MUST">1コミット = 1つの意図。無関係な変更は分割してコミットする</rule>
<rule id="commit-3" level="MUST_NOT">ユーザーの明示的な指示なく push しない</rule>
</commit-conventions>

<!-- 検証 -->
<verification>
<step id="verify-1">config.org / early-init.org を編集したら、emacs --batch でtangleが通ることを確認する（Windowsの実体は "C:\Program Files\Emacs\emacs-*\bin\emacs.exe"。emacsはPATHに無い）</step>
<step id="verify-2">生成された .el に check-parens をかけ、括弧の整合を確認する</step>
<step id="verify-3">実際の動作反映はEmacs再起動が必要。再起動はユーザーに依頼する（実行中セッションは古い設定のまま動いている点に注意）</step>
</verification>

<!-- 開発ガイドライン -->
<development-guidelines>

<!-- ファイル操作 -->
<file-operations>
<rule id="file-1" level="MUST">要求されたタスクのみを実行する - それ以上でも以下でもない</rule>
<rule id="file-2" level="MUST_NOT">タスク達成に絶対必要な場合を除き、ファイルを作成しない</rule>
<rule id="file-3" level="MUST">新規ファイル作成より既存ファイルの編集を優先する</rule>
<rule id="file-4" level="MUST_NOT">ユーザーから明示的に要求されない限り、ドキュメントファイル（*.md）やREADMEファイルを作成しない</rule>
</file-operations>

<!-- GitHub操作 -->
<github-operations>
<rule id="github-1" level="MUST">
<description>GitHub操作（issues、pull requests、releases等）には、常にghコマンドを使用する</description>
<command>gh</command>
</rule>
</github-operations>

</development-guidelines>
</claude-project-guidelines>
