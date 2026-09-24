#!/bin/zsh
# NEO Emacs を必ず隔離設定 (~/.neomacs.d) で起動する。引数なしで neomacs.app を開くと本家 ~/.emacs.d を読み、
# straight が全パッケージを Emacs 31 のバイトコードで作り直してしまうため。
# fish のログインシェル経由にして Homebrew の PATH を渡す（neomacs では exec-path-from-shell が走らない）。
# 毎フレーム出る glyph atlas 警告だけ捨てて、残りは落ちたときの調査用にログへ残す。
/opt/homebrew/bin/fish -l -c '/Applications/neomacs.app/Contents/MacOS/neomacs --init-directory ~/.neomacs.d 2>&1 | grep -av "glyph atlas" > ~/Library/Logs/neomacs.log'
