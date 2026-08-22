#!/bin/bash
# Double-clickable installer for regular players. A game app dragged onto this
# file is forwarded to install.sh; otherwise every Steam library is searched.
cd "$(dirname "$0")" || exit 1
./install.sh "$@"
status=$?
echo ""
if [ "$status" -eq 0 ]; then
    echo "Installation complete. / 安装完成。"
else
    echo "Installation failed (status $status). / 安装失败。"
fi
read -r -p "Press Return to close this window... / 按回车键关闭窗口……"
exit "$status"
