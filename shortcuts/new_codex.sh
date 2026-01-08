#!/bin/bash
# Tab+O - 打开 Codex

osascript -e 'tell application "Terminal" to do script "codex"' >/dev/null 2>&1
osascript -e 'display notification "Codex" with title "ProTab"'
