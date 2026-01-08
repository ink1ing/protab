#!/bin/bash
# Tab+P - 更新 Codex CLI

osascript -e "tell application \"Terminal\" to do script \"npm install -g @openai/codex@latest\""
osascript -e 'display notification "Codex update started" with title "ProTab"'
