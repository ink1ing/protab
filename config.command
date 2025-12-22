#!/bin/bash
# ProTab Configuration Wizard
# 交互式配置向导，帮助用户设置 ProTab

# 导入配置库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh" 2>/dev/null || {
    echo "Error: Cannot load configuration library"
    exit 1
}

# 颜色和样式
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 清屏函数
clear_screen() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ "
    echo "██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗"
    echo "██████╔╝██████╔╝██║   ██║   ██║   ███████║██████╔╝"
    echo "██╔═══╝ ██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗"
    echo "██║     ██║  ██║╚██████╔╝   ██║   ██║  ██║██████╔╝"
    echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═════╝ "
    echo -e "${NC}"
    echo -e "${CYAN}Configuration Wizard${NC}"
    echo "=================================="
    echo
}

# 显示菜单
show_menu() {
    clear_screen
    echo -e "${WHITE}Choose an option:${NC}"
    echo
    echo -e "${GREEN}1.${NC} First-time setup (新安装配置)"
    echo -e "${GREEN}2.${NC} View current configuration (查看当前配置)"
    echo -e "${GREEN}3.${NC} Edit configuration (编辑配置)"
    echo -e "${GREEN}4.${NC} Validate configuration (验证配置)"
    echo -e "${GREEN}5.${NC} Reset to defaults (重置为默认)"
    echo -e "${GREEN}6.${NC} Backup/Restore (备份/恢复)"
    echo -e "${GREEN}7.${NC} Install to system (安装到系统)"
    echo -e "${GREEN}8.${NC} Uninstall (卸载)"
    echo
    echo -e "${RED}0.${NC} Exit (退出)"
    echo
}

# 首次安装配置
first_time_setup() {
    clear_screen
    echo -e "${YELLOW}${BOLD}First-time Setup${NC}"
    echo "=================="
    echo

    # 检测当前环境
    echo -e "${CYAN}Detecting environment...${NC}"
    local current_dir="$(pwd)"
    local user_home="$HOME"

    echo "Current directory: $current_dir"
    echo "User home: $user_home"
    echo

    # 询问工作目录
    echo -e "${WHITE}Configure working directory:${NC}"
    echo "Default: $current_dir"
    read -p "Enter working directory (press Enter for default): " work_dir

    if [ -z "$work_dir" ]; then
        work_dir="$current_dir"
    fi

    # 验证目录
    if [ ! -d "$work_dir" ]; then
        echo -e "${RED}Directory does not exist: $work_dir${NC}"
        read -p "Create directory? (y/N): " create_dir
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            mkdir -p "$work_dir" || {
                echo -e "${RED}Failed to create directory${NC}"
                return 1
            }
        else
            return 1
        fi
    fi

    # 询问 Claude 配置目录
    echo
    echo -e "${WHITE}Configure Claude directory:${NC}"
    local claude_dir="$user_home/.claude"
    echo "Default: $claude_dir"
    read -p "Enter Claude config directory (press Enter for default): " input_claude

    if [ -n "$input_claude" ]; then
        claude_dir="$input_claude"
    fi

    # 询问应用名称
    echo
    echo -e "${WHITE}Configure application settings:${NC}"
    read -p "Application name [ProTab]: " app_name
    if [ -z "$app_name" ]; then
        app_name="ProTab"
    fi

    read -p "Notification title [$app_name]: " notif_title
    if [ -z "$notif_title" ]; then
        notif_title="$app_name"
    fi

    # 询问键盘设置
    echo
    echo -e "${WHITE}Configure keyboard settings:${NC}"
    read -p "Key press timeout in milliseconds [500]: " timeout_ms
    if [ -z "$timeout_ms" ] || ! [[ "$timeout_ms" =~ ^[0-9]+$ ]]; then
        timeout_ms=500
    fi

    # 询问 R2 配置
    echo
    echo -e "${WHITE}Configure R2 storage (optional):${NC}"
    read -p "R2 bucket name [r2]: " bucket_name
    if [ -z "$bucket_name" ]; then
        bucket_name="r2"
    fi

    # 生成配置文件
    echo
    echo -e "${CYAN}Generating configuration...${NC}"

    cat > "$work_dir/config.json" << EOF
{
  "project": {
    "name": "$app_name",
    "version": "1.0.0"
  },
  "paths": {
    "work_directory": "$work_dir",
    "claude_config_dir": "$claude_dir",
    "core_inject_dir": "\${HOME}/Desktop/CoreInject",
    "shortcuts_dir": "\${WORK_DIR}/shortcuts"
  },
  "keyboard": {
    "trigger_key": "tab",
    "wait_timeout_ms": $timeout_ms,
    "shortcuts": {
      "c": "start_api.sh",
      "a": "auth_api.sh",
      "m": "edit_claude_md.sh",
      "j": "edit_settings_json.sh",
      "l": "new_claude_code.sh",
      "u": "update_claude_code.sh",
      "i": "start_core_inject.sh",
      "f": "open_force_quit.sh",
      "t": "new_terminal.sh",
      "p": "new_private_tab.sh",
      "b": "upload_to_r2.sh",
      "r": "clean_ram.sh",
      "q": "network_test.sh",
      "s": "screenshot.sh",
      "v": "record.sh"
    }
  },
  "services": {
    "api": {
      "name": "copilot-api",
      "commands": {
        "start": "copilot-api start",
        "auth": "copilot-api auth"
      }
    },
    "core_inject": {
      "name": "core-inject",
      "startup_script": "秋城落叶_启动.command"
    }
  },
  "r2": {
    "bucket_name": "$bucket_name",
    "default_region": "auto"
  },
  "ui": {
    "notification_title": "$notif_title",
    "app_name": "$app_name",
    "terminal_app": "Terminal",
    "editor_app": "TextEdit"
  },
  "system": {
    "require_accessibility_permission": true,
    "auto_start": false,
    "debug_mode": false
  }
}
EOF

    echo -e "${GREEN}Configuration created: $work_dir/config.json${NC}"

    # 验证配置
    export PROTAB_CONFIG="$work_dir/config.json"
    if validate_config; then
        echo -e "${GREEN}Configuration is valid!${NC}"
    else
        echo -e "${YELLOW}Configuration has warnings${NC}"
    fi

    echo
    read -p "Press Enter to continue..."
}

# 查看当前配置
view_config() {
    clear_screen
    echo -e "${YELLOW}${BOLD}Current Configuration${NC}"
    echo "===================="
    echo

    if ! init_config 2>/dev/null; then
        echo -e "${RED}No configuration found${NC}"
        echo "Please run first-time setup first."
        echo
        read -p "Press Enter to continue..."
        return
    fi

    show_config
    echo
    read -p "Press Enter to continue..."
}

# 编辑配置
edit_config() {
    clear_screen
    echo -e "${YELLOW}${BOLD}Edit Configuration${NC}"
    echo "=================="
    echo

    if ! init_config 2>/dev/null; then
        echo -e "${RED}No configuration found${NC}"
        echo "Please run first-time setup first."
        echo
        read -p "Press Enter to continue..."
        return
    fi

    echo "Configuration file: $CONFIG_FILE"
    echo
    echo -e "${WHITE}Choose editor:${NC}"
    echo "1. TextEdit (GUI)"
    echo "2. nano (Terminal)"
    echo "3. vim (Terminal)"
    echo "4. VS Code (if available)"
    echo
    read -p "Choice [1]: " editor_choice

    case "$editor_choice" in
        2) nano "$CONFIG_FILE" ;;
        3) vim "$CONFIG_FILE" ;;
        4)
            if command -v code &> /dev/null; then
                code "$CONFIG_FILE"
            else
                echo "VS Code not found, using TextEdit"
                open -a TextEdit "$CONFIG_FILE"
            fi
            ;;
        *) open -a TextEdit "$CONFIG_FILE" ;;
    esac

    echo
    echo "Configuration file opened for editing."
    read -p "Press Enter when done editing..."

    # 验证编辑后的配置
    if validate_config; then
        echo -e "${GREEN}Configuration is valid${NC}"
    else
        echo -e "${RED}Configuration has errors${NC}"
    fi

    echo
    read -p "Press Enter to continue..."
}

# 验证配置
validate_config_menu() {
    clear_screen
    echo -e "${YELLOW}${BOLD}Validate Configuration${NC}"
    echo "======================"
    echo

    if ! init_config 2>/dev/null; then
        echo -e "${RED}No configuration found${NC}"
        echo "Please run first-time setup first."
        echo
        read -p "Press Enter to continue..."
        return
    fi

    validate_config
    echo
    read -p "Press Enter to continue..."
}

# 重置为默认配置
reset_config() {
    clear_screen
    echo -e "${YELLOW}${BOLD}Reset Configuration${NC}"
    echo "==================="
    echo

    echo -e "${RED}Warning: This will overwrite your current configuration!${NC}"
    read -p "Are you sure? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        first_time_setup
    fi
}

# 备份和恢复
backup_restore() {
    clear_screen
    echo -e "${YELLOW}${BOLD}Backup & Restore${NC}"
    echo "================"
    echo

    echo "1. Create backup"
    echo "2. Restore from backup"
    echo "3. List backups"
    echo
    read -p "Choice: " backup_choice

    local backup_dir="$HOME/.protab/backups"
    mkdir -p "$backup_dir"

    case "$backup_choice" in
        1)
            if [ ! -f "$CONFIG_FILE" ]; then
                echo -e "${RED}No configuration to backup${NC}"
                return
            fi
            local timestamp=$(date +%Y%m%d_%H%M%S)
            local backup_file="$backup_dir/config_$timestamp.json"
            cp "$CONFIG_FILE" "$backup_file"
            echo -e "${GREEN}Configuration backed up to: $backup_file${NC}"
            ;;
        2)
            echo "Available backups:"
            ls -la "$backup_dir"/config_*.json 2>/dev/null || {
                echo "No backups found"
                return
            }
            echo
            read -p "Enter backup filename: " backup_name
            if [ -f "$backup_dir/$backup_name" ]; then
                cp "$backup_dir/$backup_name" "$CONFIG_FILE"
                echo -e "${GREEN}Configuration restored${NC}"
            else
                echo -e "${RED}Backup file not found${NC}"
            fi
            ;;
        3)
            echo "Available backups:"
            ls -la "$backup_dir"/config_*.json 2>/dev/null || echo "No backups found"
            ;;
    esac

    echo
    read -p "Press Enter to continue..."
}

# 安装到系统
install_system() {
    clear_screen
    echo -e "${YELLOW}${BOLD}Install to System${NC}"
    echo "=================="
    echo

    if [ ! -f "$SCRIPT_DIR/config.json" ]; then
        echo -e "${RED}No configuration found in current directory${NC}"
        echo "Please run first-time setup first."
        echo
        read -p "Press Enter to continue..."
        return
    fi

    install_config "$SCRIPT_DIR/config.json"

    echo
    echo "To make the configuration persistent, add to your shell profile:"
    echo "export PROTAB_CONFIG=\"$HOME/.protab/config.json\""
    echo
    read -p "Press Enter to continue..."
}

# 卸载
uninstall() {
    clear_screen
    echo -e "${RED}${BOLD}Uninstall ProTab${NC}"
    echo "================"
    echo

    echo -e "${RED}This will remove all ProTab configuration and data!${NC}"
    echo "The following will be removed:"
    echo "- Configuration directory: $HOME/.protab"
    echo "- System configurations"
    echo "- Autostart settings"
    echo
    read -p "Are you sure? Type 'yes' to confirm: " confirm

    if [ "$confirm" = "yes" ]; then
        # 停止运行的进程
        pkill -f "tab_monitor" 2>/dev/null || true

        # 删除配置目录
        rm -rf "$HOME/.protab"

        # 删除自动启动
        rm -f "$HOME/Library/LaunchAgents/com.protab.plist" 2>/dev/null || true

        echo -e "${GREEN}ProTab uninstalled successfully${NC}"
    else
        echo "Uninstall cancelled"
    fi

    echo
    read -p "Press Enter to continue..."
}

# 主循环
main_loop() {
    while true; do
        show_menu
        read -p "Enter your choice: " choice

        case "$choice" in
            1) first_time_setup ;;
            2) view_config ;;
            3) edit_config ;;
            4) validate_config_menu ;;
            5) reset_config ;;
            6) backup_restore ;;
            7) install_system ;;
            8) uninstall ;;
            0)
                echo -e "${GREEN}Thank you for using ProTab!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                sleep 1
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    local missing_deps=()

    # 检查 jq（可选但推荐）
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq not found. Install with: brew install jq${NC}"
        echo "Some features may be limited without jq."
        echo
    fi

    return 0
}

# 主程序入口
main() {
    # 检查是否以脚本方式运行
    if [ $# -gt 0 ]; then
        case "$1" in
            "setup") first_time_setup ;;
            "show") view_config ;;
            "validate") validate_config_menu ;;
            *)
                echo "Usage: $0 [setup|show|validate]"
                exit 1
                ;;
        esac
        exit 0
    fi

    # 检查依赖
    check_dependencies

    # 运行主循环
    main_loop
}

# 运行主程序
main "$@"