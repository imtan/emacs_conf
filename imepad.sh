#!/bin/sh
# imepad.sh — Emacs を入力窓にして、書いた文字を元のアプリへ送る
# macOS / Linux (Wayland, X11) 共通。グローバルショートカットにこのスクリプトを割り当てる。
#
#   imepad.sh [paste|type|copy]
#     paste (既定) クリップボードに入れて、元のウィンドウで貼り付ける
#     type         キー入力として直接打ち込む（貼り付けできないゲーム向け。Linux のみ）
#     copy         クリップボードに入れるだけ
#
# 環境変数（任意）
#   IMEPAD_EMACSCLIENT  emacsclient のパス
#   IMEPAD_SOCKET       接続先のサーバー名（emacsclient -s）。NeoEmacs 宛なら neomacs
#   IMEPAD_FRAME        小窓のフレームパラメータ
#   IMEPAD_PASTE_DELAY  元のウィンドウに戻ってから貼るまでの待ち秒（既定 0.15）
#   IMEPAD_TYPE_DELAY   type で 1 文字ごとに空ける時間 ms（既定 30。取りこぼすゲームなら増やす）
#   IMEPAD_PASTE_CMD    貼り付けに使うコマンドを差し替える（例: 端末用に Ctrl+Shift+V）

set -u

mode=${1:-${IMEPAD_MODE:-paste}}
frame=${IMEPAD_FRAME:-'((name . "imepad") (width . 72) (height . 10) (left . 0.5) (top . 0.4))'}
delay=${IMEPAD_PASTE_DELAY:-0.15}
socket=${IMEPAD_SOCKET:-}
type_delay=${IMEPAD_TYPE_DELAY:-30}

case $mode in
  paste|type|copy) ;;
  *) echo "usage: imepad.sh [paste|type|copy]" >&2; exit 2 ;;
esac

has() { command -v "$1" >/dev/null 2>&1; }

# ホットキーデーモン経由だと PATH が最小限のことが多いので補う
PATH=$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin
export PATH

# ---- 環境の判定 ---------------------------------------------------------------
# platform: macos / wayland / x11
# wm:       Wayland で元のウィンドウに戻す手段（hyprland / niri / sway / kde / 空）
wm=
if [ "$(uname -s)" = Darwin ]; then
  platform=macos
elif [ -n "${WAYLAND_DISPLAY:-}" ]; then
  platform=wayland
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && has hyprctl; then
    wm=hyprland
  elif [ -n "${NIRI_SOCKET:-}" ] && has niri; then
    wm=niri
  elif [ -n "${SWAYSOCK:-}" ] && has swaymsg && has jq; then
    wm=sway
  else
    case ${XDG_CURRENT_DESKTOP:-} in
      *KDE*) has kdotool && wm=kde ;;
    esac
  fi
elif [ -n "${DISPLAY:-}" ]; then
  platform=x11
else
  echo "imepad: no graphical session found" >&2
  exit 1
fi

notify() {
  case $platform in
    macos) osascript -e "display notification \"$1\" with title \"imepad\"" >/dev/null 2>&1 ;;
    *) has notify-send && notify-send imepad "$1" ;;
  esac
  echo "imepad: $1" >&2
}

emacsclient=${IMEPAD_EMACSCLIENT:-}
if [ -z "$emacsclient" ]; then
  for c in emacsclient /Applications/Emacs.app/Contents/MacOS/bin/emacsclient; do
    if has "$c" || [ -x "$c" ]; then emacsclient=$c; break; fi
  done
fi
[ -n "$emacsclient" ] || { notify "emacsclient が見つかりません"; exit 1; }

# ---- 1. 今のウィンドウを覚える ---------------------------------------------
target=
case $platform in
  macos)
    target=$(osascript -e 'id of application (path to frontmost application as text)' 2>/dev/null) ;;
  x11)
    has xdotool && target=$(xdotool getactivewindow 2>/dev/null) ;;
  wayland)
    case $wm in
      hyprland)
        target=$(hyprctl activewindow -j 2>/dev/null |
                 sed -n 's/.*"address": *"\(0x[0-9a-fA-F]*\)".*/\1/p' | head -n 1) ;;
      niri)
        target=$(niri msg --json focused-window 2>/dev/null |
                 sed -n 's/.*"id": *\([0-9][0-9]*\).*/\1/p' | head -n 1) ;;
      sway)
        target=$(swaymsg -t get_tree 2>/dev/null |
                 jq -r '.. | select(.focused? == true) | .id' | head -n 1) ;;
      kde)
        target=$(kdotool getactivewindow 2>/dev/null) ;;
    esac ;;
esac

# ---- 2. Emacs の小窓で書く（閉じるまで待つ） ---------------------------------
tmproot=${TMPDIR:-/tmp}
dir=$(mktemp -d "${tmproot%/}/imepad.XXXXXX") || exit 1
trap 'rm -rf "$dir"' EXIT
trap 'exit 130' INT TERM
file=$dir/imepad-$$.txt
: > "$file"

if ! "$emacsclient" ${socket:+-s "$socket"} -c -F "$frame" "$file" >/dev/null 2>&1; then
  notify "emacsclient が失敗しました（Emacs${socket:+ ($socket)} は起動して (imepad-setup) 済みですか？）"
  exit 1
fi

[ -s "$file" ] || exit 0   # C-c C-k か空のまま閉じた

# ---- 3. 元のアプリへ送る ------------------------------------------------------
copy_to_clipboard() {
  case $platform in
    # pbcopy はロケールが UTF-8 でないと日本語が化ける
    macos) LC_ALL=en_US.UTF-8 pbcopy < "$file" ;;
    wayland) has wl-copy && wl-copy < "$file" >/dev/null 2>&1 ;;
    x11)
      # xclip / xsel は常駐して中身を渡し続ける。出力を閉じないとホットキー側が待たされる
      if has xclip; then xclip -selection clipboard -i < "$file" >/dev/null 2>&1
      elif has xsel; then xsel --clipboard --input < "$file" >/dev/null 2>&1
      else false
      fi ;;
  esac
}

refocus() {
  [ -n "$target" ] || return 0
  case $platform in
    macos) osascript -e "tell application id \"$target\" to activate" ;;
    x11)
      if has timeout; then timeout 2 xdotool windowactivate --sync "$target"
      else xdotool windowactivate --sync "$target"
      fi ;;
    wayland)
      case $wm in
        hyprland) hyprctl dispatch focuswindow "address:$target" ;;
        niri) niri msg action focus-window --id "$target" ;;
        sway) swaymsg "[con_id=$target] focus" ;;
        kde) kdotool windowactivate "$target" ;;
      esac ;;
  esac >/dev/null 2>&1
}

# 直接打ち込む。できなければ失敗を返す
# ホットキー経由だとロケールが POSIX のことがあり、そのままだと日本語を読めないので UTF-8 を指定
type_text() {
  case $platform in
    wayland) has wtype && LC_ALL=C.UTF-8 wtype -d "$type_delay" - < "$file" 2>/dev/null ;;
    x11) has xdotool &&
      LC_ALL=C.UTF-8 xdotool type --clearmodifiers --delay "$type_delay" --file "$file" ;;
    *) false ;;
  esac
}

# 貼り付けキー（Ctrl+V / Cmd+V）を送る。できなければ失敗を返す
paste_keys() {
  if [ -n "${IMEPAD_PASTE_CMD:-}" ]; then
    sh -c "$IMEPAD_PASTE_CMD"
    return
  fi
  case $platform in
    macos)
      osascript -e 'tell application "System Events" to keystroke "v" using command down' ;;
    wayland)
      # wtype は KDE / GNOME では動かない（virtual-keyboard 非対応）ので ydotool に回す
      { has wtype && wtype -M ctrl v -m ctrl 2>/dev/null; } ||
        { has ydotool && ydotool key 29:1 47:1 47:0 29:0 >/dev/null 2>&1; } ;;
    x11)
      has xdotool && xdotool key --clearmodifiers ctrl+v ;;
  esac
}

copy_to_clipboard || notify "クリップボードにコピーできませんでした（wl-clipboard / xclip / xsel）"
[ "$mode" = copy ] && exit 0

# macOS は小窓を閉じても Emacs が前面に残るので、戻り先が分からなければ貼らない
if [ "$platform" = macos ] && [ -z "$target" ]; then
  notify "元のアプリが分からないので、クリップボードにコピーだけしました"
  exit 0
fi

refocus
sleep "$delay"

if [ "$mode" = type ]; then
  type_text && exit 0
  notify "直接入力できなかったので貼り付けます"
fi
paste_keys || notify "貼り付けキーを送れませんでした。クリップボードには入っています"
