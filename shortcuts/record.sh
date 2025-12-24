#!/bin/bash
# 录屏功能

screencapture -v ~/Desktop/recording_$(date +%Y%m%d_%H%M%S).mov

# 显示通知
osascript -e 'display notification "Recording saved to Desktop" with title "ProTab"'
