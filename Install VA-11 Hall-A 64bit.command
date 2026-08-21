#!/bin/bash
# Double-clickable installer for regular players: runs install.sh in a Terminal window.
# If macOS blocks the first double-click, right-click the file and choose Open.
cd "$(dirname "$0")"
./install.sh
echo ""
read -r -p "Press Return to close this window..."
