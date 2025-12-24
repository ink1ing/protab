#!/bin/bash
# 快捷键截图脚本

screencapture ~/Desktop/screenshot_$(date +%Y%m%d_%H%M%S).png

# 显示通知
osascript -e 'display notification "Screenshot saved to Desktop" with title "ProTab"'