#!/bin/bash
# Double-clickable installer for regular players. A game app dragged onto this
# file is forwarded to install.sh; otherwise every Steam library is searched.
cd "$(dirname "$0")" || exit 1

preferred="${VA11_LANGUAGE:-}"
if [ -z "$preferred" ]; then
    preferred="$(defaults read -g AppleLanguages 2>/dev/null | sed -n '2{s/[[:space:]]*"\([^"]*\)".*/\1/p;q;}' || true)"
fi
case "${preferred:-${LANG:-en}}" in
    zh*|ZH*) language_code="zh" ;;
    *) language_code="en" ;;
esac

export VA11_LANGUAGE="$language_code"
./install.sh "$@"
status=$?
echo ""
if [ "$language_code" = "zh" ]; then
    if [ "$status" -eq 0 ]; then
        echo "安装完成。"
    else
        echo "安装失败（状态码 ${status}）。"
    fi
    prompt="按回车键关闭窗口……"
else
    if [ "$status" -eq 0 ]; then
        echo "Installation complete."
    else
        echo "Installation failed (status $status)."
    fi
    prompt="Press Return to close this window..."
fi
read -r -p "$prompt"
exit "$status"
