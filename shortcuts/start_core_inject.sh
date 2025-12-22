#!/bin/bash
# Tab+I - 启动Core Inject


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

# 获取通用配置
WORK_DIR=$(get_config "paths.work_directory")
CLAUDE_DIR=$(get_config "paths.claude_config_dir")
APP_NAME=$(get_config "ui.notification_title")
TERMINAL_APP=$(get_config "ui.terminal_app")
EDITOR_APP=$(get_config "ui.editor_app")

# 切换到工作目录
if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    cd "$WORK_DIR"
else
    echo "Error: Work directory not found: $WORK_DIR" >&2
    exit 1
fi


osascript -e 'display notification "Core Inject started" with title "Cozy"'