#!/bin/bash
# Tab+T - 新建终端

osascript -e 'tell application "Terminal" to do script ""' >/dev/null 2>&1
osascript -e 'display notification "New terminal" with title "ProTab"'