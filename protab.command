#!/bin/bash
# Copilot API 交互式控制脚本
# 提供多种API操作选项

# 获取用户Claude配置路径的函数
get_claude_path() {
    # 尝试多种可能的路径
    local possible_paths=(
        "$HOME/.claude"
        "/Users/$USER/.claude"
        "/Users/$(whoami)/.claude"
    )

    for path in "${possible_paths[@]}"; do
        if [ -d "$path" ] && [ -f "$path/CLAUDE.md" ]; then
            echo "$path"
            return 0
        fi
    done

    # 如果找不到，尝试搜索用户目录
    local search_result
    search_result=$(find /Users -maxdepth 2 -name ".claude" -type d 2>/dev/null | head -1)
    if [ -n "$search_result" ] && [ -f "$search_result/CLAUDE.md" ]; then
        echo "$search_result"
        return 0
    fi

    # 如果仍然找不到，使用交互式选择
    echo "未找到Claude配置目录，请手动选择..."
    local selected_path
    selected_path=$(osascript -e '
        try
            tell application "System Events"
                activate
                set theFolder to choose folder with prompt "请选择您的 .claude 配置文件夹："
                return POSIX path of theFolder
            end tell
        on error
            return ""
        end try
    ' 2>/dev/null)

    if [ -n "$selected_path" ]; then
        # 移除末尾的斜杠
        echo "${selected_path%/}"
        return 0
    fi

    # 最后回退到默认路径
    echo "$HOME/.claude"
    return 1
}

# 缓存Claude路径到临时文件
CLAUDE_PATH_CACHE="/tmp/protab_claude_path"

get_cached_claude_path() {
    if [ -f "$CLAUDE_PATH_CACHE" ]; then
        local cached_path=$(cat "$CLAUDE_PATH_CACHE")
        # 验证缓存的路径是否仍然有效
        if [ -d "$cached_path" ]; then
            echo "$cached_path"
            return 0
        else
            # 缓存无效，删除
            rm -f "$CLAUDE_PATH_CACHE"
        fi
    fi

    # 重新检测并缓存
    local claude_path=$(get_claude_path)
    echo "$claude_path" > "$CLAUDE_PATH_CACHE"
    echo "$claude_path"
}

# 清屏函数
clear_screen() {
    clear
}


# 设置全局快捷键
setup_global_shortcuts() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 检查是否已有守护进程运行
    if pgrep -f "tab_monitor" > /dev/null; then
        return 0
    fi

    # 编译Tab监听器
    if [ ! -f "$script_dir/tab_monitor" ]; then
        if swiftc "$script_dir/swift/ProTabConfig.swift" "$script_dir/swift/tab_monitor.swift" "$script_dir/swift/main.swift" -o "$script_dir/tab_monitor" 2>/dev/null; then
            echo "Ready"
        else
            echo "Failed"
            return 1
        fi
    fi

    # 后台运行Tab键监听器
    "$script_dir/tab_monitor" &
}

# 显示菜单
show_menu() {
    echo -e "\033[34m"
    echo "██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ "
    echo "██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗"
    echo "██████╔╝██████╔╝██║   ██║   ██║   ███████║██████╔╝"
    echo "██╔═══╝ ██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗"
    echo "██║     ██║  ██║╚██████╔╝   ██║   ██║  ██║██████╔╝"
    echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═════╝ "
    echo -e "\033[0m"
    echo ""
    echo "cozy v2.0"
    echo "c. start copilot-api"
    echo "a. auth copilot-api"
    echo "m. edit claude.md"
    echo "j. edit settings.json"
    echo "l. new claude code"
    echo "u. update claude code"
    echo "f. open force quit"
    echo "t. new system terminal"
    echo "p. new private tab"
    echo "r. free up ram"
    echo "q. test web&ip"
    echo "s. screenshot"
    echo "v. screen record"
    echo "x. toggle vpn"
    echo -n ""
}

# 在新终端中执行命令的函数
run_in_new_terminal() {
    local command="$1"
    local title="$2"

    # 使用 osascript 在新的终端窗口中运行命令
    osascript -e "
        tell application \"Terminal\"
            activate
            do script \"echo '执行: $command'; echo ''; $command\"
            set custom title of front window to \"$title\"
        end tell
    "
}


# 系统内存清理函数
clear_system_memory() {
    # 获取脚本所在目录
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 首先尝试使用 Rust 版本
    if [ -f "$script_dir/rust/target/release/freeup_ram_rust" ]; then
        local result=$("$script_dir/rust/target/release/freeup_ram_rust" 2>&1 | tail -1)
        osascript -e "display notification \"$result\" with title \"Cozy - Rust\""
    else
        # 回退到系统 purge 命令
        if sudo purge 2>/dev/null; then
            osascript -e 'display notification "内存清理完成" with title "Cozy"'
        else
            osascript -e 'display notification "内存清理失败" with title "Cozy"'
        fi
    fi
}

# 网络连接测试函数
test_network_connection() {
    # 测试中国网络连通性
    local cn_status="❌"
    if curl -s --max-time 3 --connect-timeout 2 "https://www.gov.cn" > /dev/null 2>&1 && \
       curl -s --max-time 3 --connect-timeout 2 "https://www.aliyun.com" > /dev/null 2>&1 && \
       ping -c 1 -W 2000 114.114.114.114 > /dev/null 2>&1; then
        cn_status="✅"
    fi

    # 测试国际网络连通性
    local global_status="❌"
    if curl -s --max-time 3 --connect-timeout 2 "https://www.cloudflare.com" > /dev/null 2>&1 && \
       curl -s --max-time 3 --connect-timeout 2 "https://www.apple.com" > /dev/null 2>&1 && \
       (ping -c 1 -W 2000 1.1.1.1 > /dev/null 2>&1 || ping -c 1 -W 2000 8.8.8.8 > /dev/null 2>&1); then
        global_status="✅"
    fi

    # 获取IP地址
    local ip_result
    local ip_addr=$(curl -s --max-time 3 --connect-timeout 2 "https://ifconfig.me" 2>/dev/null | head -1)
    if [ -n "$ip_addr" ]; then
        ip_result="IP: ${ip_addr}"
    else
        ip_result="IP: unknown"
    fi

    # 通过系统通知显示结果
    osascript -e "display notification \"CN: ${cn_status} Global: ${global_status} ${ip_result}\" with title \"Network Test\""
}

# 首次启动检测和欢迎
first_time_setup() {
    local setup_flag="/tmp/protab_setup_done"

    if [ ! -f "$setup_flag" ]; then
        clear
        echo -e "\033[34m"
        echo "██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ "
        echo "██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗"
        echo "██████╔╝██████╔╝██║   ██║   ██║   ███████║██████╔╝"
        echo "██╔═══╝ ██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗"
        echo "██║     ██║  ██║╚██████╔╝   ██║   ██║  ██║██████╔╝"
        echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═════╝ "
        echo -e "\033[0m"
        echo ""
        echo "🎉 欢迎使用 ProTab!"
        echo ""
        echo "首次启动配置中..."
        echo "正在检测Claude配置路径..."

        # 预先检测Claude路径，如果需要用户选择会在这里进行
        local claude_path=$(get_claude_path)
        if [ $? -eq 0 ]; then
            echo "✅ Claude配置路径: $claude_path"
        else
            echo "⚠️  未找到Claude配置，已使用默认路径"
        fi

        echo ""
        echo "🚀 设置完成！按任意键继续..."
        read -n 1

        # 标记设置完成
        touch "$setup_flag"
    fi
}

# 主循环
main_loop() {
    # 首次启动检测
    first_time_setup

    # 设置全局快捷键
    setup_global_shortcuts

    while true; do
        clear_screen
        show_menu

        # 读取用户输入
        read -n 1 choice
        echo  # 换行

        case $choice in
            c)
                # 检查并关闭现有的copilot-api进程
                existing_pid=$(pgrep -f "copilot-api")
                if [ -n "$existing_pid" ]; then
                    echo "Existed copilot-api process (PID: $existing_pid), closing..."

                    # 关闭包含copilot-api的终端窗口/标签页
                    osascript -e "
                        tell application \"Terminal\"
                            repeat with theWindow in windows
                                repeat with theTab in tabs of theWindow
                                    try
                                        set tabContents to (do shell script \"ps aux | grep copilot-api | grep -v grep | awk '{print \\$2}'\" )
                                        if tabContents contains \"$existing_pid\" then
                                            close theTab
                                            exit repeat
                                        end if
                                    end try
                                end repeat
                            end repeat
                        end tell
                    " 2>/dev/null || true

                    # 或者使用更简单的方法：根据窗口标题关闭
                    osascript -e "
                        tell application \"Terminal\"
                            repeat with theWindow in windows
                                repeat with theTab in tabs of theWindow
                                    if custom title of theTab contains \"Copilot API Server\" then
                                        close theTab
                                        exit repeat
                                    end if
                                end repeat
                            end repeat
                        end tell
                    " 2>/dev/null || true

                    # 终止进程
                    kill $existing_pid
                    sleep 1
                    # 等待进程完全结束
                    while pgrep -f "copilot-api" > /dev/null; do
                        sleep 0.5
                    done
                fi

                run_in_new_terminal "copilot-api start" "Copilot API Server"
                osascript -e 'display notification "Copilot API started" with title "Cozy"'
                ;;
            a)
                run_in_new_terminal "copilot-api auth" "Copilot API Auth"
                osascript -e 'display notification "Copilot API auth started" with title "Cozy"'
                ;;
            m)
                claude_path=$(get_cached_claude_path)
                open "$claude_path/CLAUDE.md"
                osascript -e 'display notification "Claude.md opened" with title "Cozy"'
                ;;
            j)
                claude_path=$(get_cached_claude_path)
                open "$claude_path/settings.json"
                osascript -e 'display notification "Settings.json opened" with title "Cozy"'
                ;;
            u)
                run_in_new_terminal "npm install -g @anthropic-ai/claude-code@latest" "Claude Code 升级"
                osascript -e 'display notification "Claude Code update started" with title "Cozy"'
                ;;
            f)
                osascript -e "tell application \"System Events\" to key code 53 using {option down, command down}"
                osascript -e 'display notification "Force Quit opened" with title "Cozy"'
                ;;
            t)
                osascript -e "tell application \"Terminal\" to do script \"\""
                osascript -e 'display notification "New terminal opened" with title "Cozy"'
                ;;
            p)
                osascript -e "tell application \"Safari\" to activate" -e "tell application \"System Events\" to keystroke \"n\" using {command down, shift down}"
                osascript -e 'display notification "Private tab opened" with title "Cozy"'
                ;;
            l)
                run_in_new_terminal "claude" "Claude Code"
                osascript -e 'display notification "Claude Code started" with title "Cozy"'
                ;;
            r)
                clear_system_memory >/dev/null 2>&1
                ;;
            q)
                test_network_connection
                ;;
            s)
                screencapture ~/Desktop/screenshot_$(date +%Y%m%d_%H%M%S).png
                osascript -e 'display notification "Screenshot saved to Desktop" with title "Cozy"'
                ;;
            v)
                screencapture -v ~/Desktop/recording_$(date +%Y%m%d_%H%M%S).mov >/dev/null 2>&1
                osascript -e 'display notification "Recording saved to Desktop" with title "Cozy"'
                ;;
            x)
                local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                "$script_dir/shortcuts/toggle_vpn.sh" >/dev/null 2>&1
                ;;
            *)
                ;;
        esac
    done
}

# 启动主程序
main_loop