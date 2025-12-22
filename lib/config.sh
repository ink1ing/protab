#!/bin/bash
# ProTab Configuration Library
# 提供配置文件读取和管理功能

# 配置文件路径
CONFIG_FILE=""
CONFIG_DIR=""

# 初始化配置系统
init_config() {
    # 确定配置文件位置
    if [ -n "$PROTAB_CONFIG" ]; then
        CONFIG_FILE="$PROTAB_CONFIG"
    elif [ -f "$HOME/.protab/config.json" ]; then
        CONFIG_FILE="$HOME/.protab/config.json"
    elif [ -f "$(dirname "$0")/config.json" ]; then
        CONFIG_FILE="$(dirname "$0")/config.json"
    else
        echo "Error: No configuration file found" >&2
        return 1
    fi

    CONFIG_DIR=$(dirname "$CONFIG_FILE")

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file not found: $CONFIG_FILE" >&2
        return 1
    fi

    return 0
}

# 读取配置值
# 用法: get_config "paths.work_directory"
get_config() {
    local key="$1"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration not initialized" >&2
        return 1
    fi

    # 使用 jq 提取配置值
    if command -v jq &> /dev/null; then
        local value=$(jq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null)
        if [ -n "$value" ] && [ "$value" != "null" ]; then
            # 处理环境变量替换
            value=$(echo "$value" | sed "s|\${HOME}|$HOME|g")
            value=$(echo "$value" | sed "s|\${WORK_DIR}|$(get_work_dir)|g")
            echo "$value"
        fi
    else
        # 如果没有 jq，使用简单的 grep 和 sed 提取
        local pattern=$(echo "$key" | sed 's/\./\\./g')
        grep "\"$pattern\"" "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1
    fi
}

# 获取工作目录（特殊处理，避免循环依赖）
get_work_dir() {
    if command -v jq &> /dev/null; then
        local work_dir=$(jq -r '.paths.work_directory // empty' "$CONFIG_FILE" 2>/dev/null)
        echo "$work_dir" | sed "s|\${HOME}|$HOME|g"
    else
        echo "$(dirname "$CONFIG_FILE")"
    fi
}

# 获取快捷键映射
get_shortcut() {
    local key="$1"
    get_config "keyboard.shortcuts.$key"
}

# 获取服务配置
get_service_config() {
    local service="$1"
    local property="$2"
    get_config "services.$service.$property"
}

# 验证配置文件
validate_config() {
    init_config || return 1

    echo "Validating configuration..."

    # 检查必需的路径
    local work_dir=$(get_config "paths.work_directory")
    if [ -z "$work_dir" ]; then
        echo "Error: work_directory not configured" >&2
        return 1
    fi

    # 检查工作目录是否存在
    if [ ! -d "$work_dir" ]; then
        echo "Warning: Work directory does not exist: $work_dir"
    fi

    # 检查快捷键脚本目录
    local shortcuts_dir=$(get_config "paths.shortcuts_dir")
    if [ -n "$shortcuts_dir" ] && [ ! -d "$shortcuts_dir" ]; then
        echo "Warning: Shortcuts directory does not exist: $shortcuts_dir"
    fi

    echo "Configuration validation completed"
    return 0
}

# 显示当前配置
show_config() {
    init_config || return 1

    echo "ProTab Configuration:"
    echo "===================="
    echo "Config file: $CONFIG_FILE"
    echo "Work directory: $(get_config 'paths.work_directory')"
    echo "Claude config: $(get_config 'paths.claude_config_dir')"
    echo "Shortcuts directory: $(get_config 'paths.shortcuts_dir')"
    echo "Trigger timeout: $(get_config 'keyboard.wait_timeout_ms')ms"
    echo "Notification title: $(get_config 'ui.notification_title')"
    echo
    echo "Keyboard shortcuts:"
    local shortcuts=$(get_config "keyboard.shortcuts")
    if command -v jq &> /dev/null; then
        echo "$shortcuts" | jq -r '. | to_entries[] | "  " + .key + " -> " + .value'
    fi
}

# 创建默认配置目录
create_config_dir() {
    local config_dir="$HOME/.protab"
    mkdir -p "$config_dir"
    echo "$config_dir"
}

# 复制配置文件到用户目录
install_config() {
    local source_config="$1"
    local config_dir=$(create_config_dir)
    local target_config="$config_dir/config.json"

    if [ -f "$target_config" ]; then
        echo "Configuration already exists: $target_config"
        read -p "Overwrite? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    cp "$source_config" "$target_config"
    echo "Configuration installed to: $target_config"

    # 设置环境变量
    export PROTAB_CONFIG="$target_config"
}

# 如果直接运行此脚本，显示配置信息
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "${1:-show}" in
        "show"|"")
            show_config
            ;;
        "validate")
            validate_config
            ;;
        "install")
            install_config "${2:-config.json}"
            ;;
        *)
            echo "Usage: $0 [show|validate|install [config_file]]"
            exit 1
            ;;
    esac
fi