#!/bin/bash
# Tab+L - 打开 Claude Code

osascript -e 'tell application "Terminal" to do script "claude"' >/dev/null 2>&1
osascript -e 'display notification "Claude Code" with title "ProTab"'
