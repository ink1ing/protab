#!/bin/bash
# ProTab 主控制脚本
# 提供多种快捷操作和配置管理

# 导入配置库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh" || {
    echo "Error: Cannot load configuration library"
    echo "Please ensure lib/config.sh exists"
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
    echo -e "${CYAN}Main Control Panel${NC}"
    echo "=================================="
    echo
}

# 检查配置状态
check_config() {
    if ! init_config 2>/dev/null; then
        echo -e "${RED}Configuration not found${NC}"
        echo "Please run configuration setup first."
        echo
        echo -e "${WHITE}Options:${NC}"
        echo "1. Run quick setup: ./config.command setup"
        echo "2. Run interactive setup: ./config.command"
        echo
        return 1
    fi
    return 0
}

# 获取配置值（带默认值）
get_config_safe() {
    local key="$1"
    local default="$2"
    local value=$(get_config "$key" 2>/dev/null)
    echo "${value:-$default}"
}

# 检查依赖
check_dependencies() {
    local missing_deps=()

    # 检查 Swift 编译器
    if ! command -v swiftc &> /dev/null; then
        missing_deps+=("Swift compiler (install Xcode Command Line Tools)")
    fi

    # 检查 jq (可选)
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq not found. Some features may be limited.${NC}"
        echo "Install with: brew install jq"
        echo
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Missing dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo
        return 1
    fi

    return 0
}

# 设置全局快捷键
setup_global_shortcuts() {
    if ! check_config; then
        return 1
    fi

    local work_dir=$(get_config_safe "paths.work_directory" "$SCRIPT_DIR")
    local app_name=$(get_config_safe "ui.app_name" "ProTab")

    echo -e "${CYAN}Setting up global shortcuts...${NC}"

    # 检查是否已有守护进程运行
    if pgrep -f "tab_monitor" > /dev/null; then
        echo -e "${GREEN}Tab monitor already running${NC}"
        return 0
    fi

    # 编译Tab监听器
    if [ ! -f "$work_dir/tab_monitor" ]; then
        echo "Compiling tab monitor..."
        if [ -f "$work_dir/build.sh" ]; then
            cd "$work_dir"
            ./build.sh
        else
            # 手动编译
            if [ -f "$work_dir/ProTabConfig.swift" ] && [ -f "$work_dir/tab_monitor.swift" ]; then
                swiftc "$work_dir/ProTabConfig.swift" "$work_dir/tab_monitor.swift" -o "$work_dir/tab_monitor" 2>/dev/null
            else
                echo -e "${RED}Error: Swift source files not found${NC}"
                return 1
            fi
        fi

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Compilation successful${NC}"
        else
            echo -e "${RED}Compilation failed${NC}"
            return 1
        fi
    fi

    # 启动Tab键监听器
    echo "Starting tab monitor..."
    cd "$work_dir"
    PROTAB_CONFIG="$CONFIG_FILE" "$work_dir/tab_monitor" &

    sleep 1

    if pgrep -f "tab_monitor" > /dev/null; then
        echo -e "${GREEN}$app_name shortcuts activated!${NC}"
        echo "Press Tab + letter to trigger shortcuts"
    else
        echo -e "${RED}Failed to start tab monitor${NC}"
        return 1
    fi
}

# 停止全局快捷键
stop_global_shortcuts() {
    echo -e "${CYAN}Stopping global shortcuts...${NC}"

    local pids=$(pgrep -f "tab_monitor")
    if [ -n "$pids" ]; then
        kill $pids 2>/dev/null
        sleep 1
        if pgrep -f "tab_monitor" > /dev/null; then
            kill -9 $pids 2>/dev/null
        fi
        echo -e "${GREEN}Tab monitor stopped${NC}"
    else
        echo "Tab monitor not running"
    fi
}

# 显示状态
show_status() {
    clear_screen

    if ! check_config; then
        return 1
    fi

    local work_dir=$(get_config_safe "paths.work_directory" "Unknown")
    local app_name=$(get_config_safe "ui.app_name" "ProTab")
    local shortcuts_count=$(get_config "keyboard.shortcuts" | jq -r 'length' 2>/dev/null || echo "Unknown")

    echo -e "${WHITE}System Status:${NC}"
    echo "============="
    echo "Configuration: $CONFIG_FILE"
    echo "Work Directory: $work_dir"
    echo "App Name: $app_name"
    echo "Shortcuts Count: $shortcuts_count"
    echo

    # 检查进程状态
    if pgrep -f "tab_monitor" > /dev/null; then
        echo -e "Tab Monitor: ${GREEN}Running${NC}"
    else
        echo -e "Tab Monitor: ${RED}Stopped${NC}"
    fi

    # 检查API状态
    local api_name=$(get_config_safe "services.api.name" "copilot-api")
    if pgrep -f "$api_name" > /dev/null; then
        echo -e "API Service: ${GREEN}Running${NC}"
    else
        echo -e "API Service: ${RED}Stopped${NC}"
    fi

    echo
}

# 显示快捷键帮助
show_shortcuts() {
    clear_screen

    if ! check_config; then
        return 1
    fi

    echo -e "${WHITE}Available Shortcuts:${NC}"
    echo "==================="
    echo "Press Tab + letter to trigger:"
    echo

    # 获取快捷键映射
    local shortcuts=$(get_config "keyboard.shortcuts")
    if command -v jq &> /dev/null && [ -n "$shortcuts" ]; then
        echo "$shortcuts" | jq -r 'to_entries[] | "  Tab + \(.key) -> \(.value)"' 2>/dev/null | sort
    else
        echo "  Tab + c -> start_api.sh"
        echo "  Tab + a -> auth_api.sh"
        echo "  Tab + m -> edit_claude_md.sh"
        echo "  Tab + j -> edit_settings_json.sh"
        echo "  Tab + l -> new_claude_code.sh"
        echo "  Tab + t -> new_terminal.sh"
        echo "  Tab + s -> screenshot.sh"
        echo "  Tab + r -> clean_ram.sh"
        echo "  And more..."
    fi

    echo
    echo "Note: Shortcuts work globally when tab monitor is running"
}

# 显示主菜单
show_menu() {
    clear_screen

    echo -e "${WHITE}Choose an option:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Show Status (显示状态)"
    echo -e "${GREEN}2.${NC} Start Global Shortcuts (启动全局快捷键)"
    echo -e "${GREEN}3.${NC} Stop Global Shortcuts (停止全局快捷键)"
    echo -e "${GREEN}4.${NC} Show Shortcuts Help (快捷键帮助)"
    echo -e "${GREEN}5.${NC} Configuration (配置管理)"
    echo -e "${GREEN}6.${NC} Build & Compile (编译程序)"
    echo -e "${GREEN}7.${NC} System Tools (系统工具)"
    echo
    echo -e "${RED}0.${NC} Exit (退出)"
    echo
}

# 配置管理菜单
config_menu() {
    echo -e "${CYAN}Opening configuration wizard...${NC}"
    if [ -f "$SCRIPT_DIR/config.command" ]; then
        "$SCRIPT_DIR/config.command"
    else
        echo -e "${RED}Configuration wizard not found${NC}"
        read -p "Press Enter to continue..."
    fi
}

# 编译菜单
build_menu() {
    clear_screen
    echo -e "${YELLOW}${BOLD}Build & Compile${NC}"
    echo "==============="
    echo

    if ! check_dependencies; then
        read -p "Press Enter to continue..."
        return
    fi

    if ! check_config; then
        return
    fi

    local work_dir=$(get_config_safe "paths.work_directory" "$SCRIPT_DIR")

    echo "Work Directory: $work_dir"
    echo

    if [ -f "$work_dir/build.sh" ]; then
        echo "Running build script..."
        cd "$work_dir"
        ./build.sh
    else
        echo "Manual compilation..."
        cd "$work_dir"
        swiftc ProTabConfig.swift tab_monitor.swift -o tab_monitor
        if [ $? -eq 0 ]; then
            chmod +x tab_monitor
            echo -e "${GREEN}Compilation successful${NC}"
        else
            echo -e "${RED}Compilation failed${NC}"
        fi
    fi

    echo
    read -p "Press Enter to continue..."
}

# 系统工具菜单
system_tools_menu() {
    clear_screen
    echo -e "${YELLOW}${BOLD}System Tools${NC}"
    echo "============"
    echo

    echo "1. Clean RAM (清理内存)"
    echo "2. Network Test (网络测试)"
    echo "3. Screenshot (截图)"
    echo "4. Force Quit Apps (强制退出应用)"
    echo "0. Back (返回)"
    echo

    read -p "Choose an option: " choice

    case "$choice" in
        1)
            if [ -f "$SCRIPT_DIR/shortcuts/clean_ram.sh" ]; then
                "$SCRIPT_DIR/shortcuts/clean_ram.sh"
            fi
            ;;
        2)
            if [ -f "$SCRIPT_DIR/shortcuts/network_test.sh" ]; then
                "$SCRIPT_DIR/shortcuts/network_test.sh"
            fi
            ;;
        3)
            if [ -f "$SCRIPT_DIR/shortcuts/screenshot.sh" ]; then
                "$SCRIPT_DIR/shortcuts/screenshot.sh"
            fi
            ;;
        4)
            if [ -f "$SCRIPT_DIR/shortcuts/open_force_quit.sh" ]; then
                "$SCRIPT_DIR/shortcuts/open_force_quit.sh"
            fi
            ;;
        0) return ;;
    esac

    read -p "Press Enter to continue..."
}

# 主循环
main_loop() {
    while true; do
        show_menu
        read -p "Enter your choice: " choice

        case "$choice" in
            1) show_status; read -p "Press Enter to continue..." ;;
            2) setup_global_shortcuts; read -p "Press Enter to continue..." ;;
            3) stop_global_shortcuts; read -p "Press Enter to continue..." ;;
            4) show_shortcuts; read -p "Press Enter to continue..." ;;
            5) config_menu ;;
            6) build_menu ;;
            7) system_tools_menu ;;
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

# 主程序入口
main() {
    # 处理命令行参数
    case "${1:-}" in
        "start")
            setup_global_shortcuts
            ;;
        "stop")
            stop_global_shortcuts
            ;;
        "status")
            show_status
            read -p "Press Enter to continue..."
            ;;
        "config")
            config_menu
            ;;
        "build")
            build_menu
            ;;
        "help"|"-h"|"--help")
            echo "ProTab - Global Shortcuts System"
            echo "Usage: $0 [start|stop|status|config|build|help]"
            echo
            echo "Commands:"
            echo "  start   - Start global shortcuts"
            echo "  stop    - Stop global shortcuts"
            echo "  status  - Show system status"
            echo "  config  - Open configuration"
            echo "  build   - Build/compile system"
            echo "  help    - Show this help"
            echo
            echo "Run without arguments for interactive menu"
            ;;
        "")
            # 检查基本依赖
            check_dependencies

            # 运行主循环
            main_loop
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# 运行主程序
main "$@"