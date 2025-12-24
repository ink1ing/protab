#!/bin/bash
# 快捷键新终端脚本

osascript -e 'tell application "Terminal" to do script ""'

# 显示通知
osascript -e 'display notification "New terminal opened" with title "ProTab"'