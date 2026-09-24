; imepad.ahk — Emacs を入力窓にして、書いた文字を元のアプリへ送る（Windows / AutoHotkey v2）
;
;   Win+J        小窓を開く → C-c C-c で元のアプリに貼り付け
;   Win+Shift+J  同じく、ただしキー入力として直接打ち込む（貼り付けできないゲーム向け）
;
; Emacs 側で (require 'imepad) (imepad-setup) しておくこと。

#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== 設定 =====
; PATH に無ければフルパスで。例: "C:\Program Files\Emacs\emacs-30.2\bin\emacsclientw.exe"
EmacsClient := "emacsclientw.exe"
FrameParams := '((name . "imepad") (width . 72) (height . 10) (left . 0.5) (top . 0.4))'
PasteDelay := 100            ; 元のウィンドウに戻ってから貼るまでの待ち (ms)
RestoreClipboard := false    ; true なら貼り付け後にクリップボードを元に戻す

#j::ImePad("paste")
#+j::ImePad("type")

ImePad(mode) {
    global EmacsClient, FrameParams, PasteDelay, RestoreClipboard

    ; 1. 今のウィンドウを覚える
    target := WinExist("A")

    ; 2. Emacs の小窓で書く（閉じるまで待つ）
    dir := A_Temp "\imepad"
    DirCreate dir
    file := dir "\imepad-" A_TickCount ".txt"
    FileAppend "", file, "UTF-8-RAW"

    ; -F の中の " は \" にして渡す
    cmd := Format('"{1}" -a "" -c -F "{2}" "{3}"'
                , EmacsClient, StrReplace(FrameParams, '"', '\"'), file)
    try {
        Run cmd, , , &pid
    } catch as e {
        MsgBox "emacsclient を起動できませんでした。`n" e.Message, "imepad"
        return
    }
    ; Windows は別プロセスへのフォーカス移動を嫌うので、小窓はこちらで前に出す
    SetTitleMatchMode 3
    if (hwnd := WinWait("imepad ahk_class Emacs", , 5))
        WinActivate hwnd
    ProcessWaitClose pid

    text := FileExist(file) ? FileRead(file, "UTF-8") : ""
    try FileDelete file
    if (text = "")    ; C-c C-k か空のまま閉じた
        return

    ; 3. 元のアプリへ送る
    if (target && WinExist(target)) {
        WinActivate target
        WinWaitActive target, , 1
    }
    Sleep PasteDelay

    if (mode = "type") {
        SendText text    ; 改行は LF のまま（`n が 1 回の Enter になる）
        return
    }
    saved := RestoreClipboard ? ClipboardAll() : ""
    A_Clipboard := StrReplace(text, "`n", "`r`n")   ; Windows アプリ向けに CRLF
    ClipWait 1
    Send "^v"
    if RestoreClipboard {
        Sleep 300
        A_Clipboard := saved
    }
}
