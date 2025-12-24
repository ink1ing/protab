#!/bin/bash
# 更新 Claude Code

osascript -e "tell application \"Terminal\" to do script \"npm install -g @anthropic-ai/claude-code@latest\""

# 显示通知
osascript -e 'display notification "Claude Code update started" with title "ProTab"'
