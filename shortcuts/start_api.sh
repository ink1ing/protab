#!/bin/bash
# Tab+C - 启动API

# 导入配置库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/lib/config.sh" || {
    echo "Error: Cannot load configuration library" >&2
    exit 1
}

# 初始化配置
if ! init_config; then
    echo "Error: Failed to initialize configuration" >&2
    exit 1
fi

# 获取工作目录和应用名称
WORK_DIR=$(get_config "paths.work_directory")
APP_NAME=$(get_config "ui.notification_title")
API_NAME=$(get_service_config "api" "name")
API_START_CMD=$(get_service_config "api" "commands.start")

# 切换到工作目录
if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    cd "$WORK_DIR"
else
    echo "Error: Work directory not found: $WORK_DIR" >&2
    exit 1
fi

# 检查并关闭现有进程
existing_pid=$(pgrep -f "$API_NAME")
if [ -n "$existing_pid" ]; then
    # 关闭包含进程的终端窗口/标签页
    osascript -e "
        tell application \"Terminal\"
            set windowList to every window
            repeat with aWindow in windowList
                set tabList to every tab of aWindow
                repeat with aTab in tabList
                    if (processes of aTab) contains \"$API_NAME\" then
                        close aTab
                        exit repeat
                    end if
                end repeat
            end repeat
        end tell
    " 2>/dev/null

    # 强制终止进程
    kill -TERM $existing_pid 2>/dev/null
    sleep 1

    if pgrep -f "$API_NAME" > /dev/null; then
        kill -KILL $existing_pid 2>/dev/null
    fi

    # 等待进程完全结束
    while pgrep -f "$API_NAME" > /dev/null; do
        sleep 0.5
    done
fi

# 启动新的API服务器
osascript -e "tell application \"Terminal\" to do script \"cd '$WORK_DIR' && $API_START_CMD\""

osascript -e "display notification \"$API_NAME started\" with title \"$APP_NAME\""