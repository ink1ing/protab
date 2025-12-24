#!/bin/bash
# 新建私人标签页

osascript -e "tell application \"Safari\" to activate" -e "tell application \"System Events\" to keystroke \"n\" using {command down, shift down}"

# 显示通知
osascript -e 'display notification "Private tab opened" with title "ProTab"'
