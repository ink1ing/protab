#!/bin/bash
# Copilot API 交互式控制脚本
# 提供多种API操作选项

# 清屏函数
clear_screen() {
    clear
}

# 检查wrangler状态
check_wrangler() {
    if ! command -v wrangler &> /dev/null; then
        return 1
    fi
    return 0
}

# 设置全局快捷键
setup_global_shortcuts() {
    local script_dir="/Users/inkling/Desktop/cozy proj"

    # 检查是否已有守护进程运行
    if pgrep -f "tab_monitor" > /dev/null; then
        return 0
    fi

    # 编译Tab监听器
    if [ ! -f "$script_dir/tab_monitor" ]; then
        if swiftc "$script_dir/tab_monitor.swift" -o "$script_dir/tab_monitor" 2>/dev/null; then
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
    echo " ██████╗ ██████╗ ███████╗██╗   ██╗"
    echo "██╔════╝██╔═══██╗╚════██║╚██╗ ██╔╝"
    echo "██║     ██║   ██║    ██╔╝ ╚████╔╝ "
    echo "██║     ██║   ██║   ██╔╝   ╚██╔╝  "
    echo "╚██████╗╚██████╔╝██████╔╝    ██║   "
    echo " ╚═════╝ ╚═════╝ ╚═════╝     ╚═╝   "
    echo -e "\033[0m"
    echo ""
    echo "cozy v2.0"
    echo "c. start copilot-api"
    echo "a. auth copilot-api"
    echo "m. edit claude.md"
    echo "j. edit settings.json"
    echo "l. new claude code"
    echo "u. update claude code"
    echo "i. start core inject"
    echo "f. open force quit"
    echo "t. new system terminal"
    echo "p. new private tab"
    if check_wrangler; then
        echo "b. upload to r2"
    fi
    echo "r. free up ram"
    echo "q. test web&ip"
    echo "s. screenshot"
    echo "v. screen record"
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

# 文件上传到R2的函数
upload_to_r2() {
    # 使用AppleScript打开文件选择器
    local selected_file
    selected_file=$(osascript -e "
        try
            tell application \"System Events\"
                activate
                set theFile to choose file with prompt \"Select file to upload:\"
                return POSIX path of theFile
            end tell
        end try
    " 2>/dev/null)

    # 检查用户是否取消了选择
    if [ -z "$selected_file" ]; then
        echo "Upload cancelled"
        return 1
    fi

    # 提取原始文件名和扩展名
    local original_filename=$(basename "$selected_file")
    local extension="${original_filename##*.}"

    # 获取自定义文件名
    echo -n "Name file, enter to skip: "
    read custom_name

    # 确定最终文件名
    local final_filename
    if [ -z "$custom_name" ]; then
        final_filename="$original_filename"
    else
        if [[ "$custom_name" == *.* ]]; then
            final_filename="$custom_name"
        else
            final_filename="$custom_name.$extension"
        fi
    fi

    # 实际的R2存储桶名称
    local bucket_name="inksportal"

    # 执行上传命令，并检查真实结果
    local upload_result
    upload_result=$(wrangler r2 object put "$bucket_name/$final_filename" --file="$selected_file" --remote 2>&1)
    local upload_exit_code=$?

    if [ $upload_exit_code -eq 0 ]; then
        echo "✅ Upload success: $final_filename"
    else
        echo "❌ Upload failed"
        echo "Error: $upload_result"
        return 1
    fi
}

# 系统内存清理函数
clear_system_memory() {
    # 获取脚本所在目录
    local script_dir="/Users/inkling/Desktop/cozy proj"

    # 检查专业清理程序是否存在
    if [ ! -f "$script_dir/freeup_ram" ]; then
        # 尝试编译
        if clang -O2 -o "$script_dir/freeup_ram" "$script_dir/freeup_ram.c" 2>/dev/null; then
            :
        else
            # 回退到简单的purge命令
            if sudo purge 2>/dev/null; then
                osascript -e 'display notification "Clean completed" with title "Cozy"'
            else
                osascript -e 'display notification "Clean failed" with title "Cozy"'
            fi
            return
        fi
    fi

    # 执行专业内存清理，通过系统通知显示结果
    local result=$("$script_dir/freeup_ram" 2>&1 | tail -1)
    osascript -e "display notification \"$result\" with title \"Cozy\""
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

# 主循环
main_loop() {
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
                open "/Users/inkling/.claude/CLAUDE.md"
                osascript -e 'display notification "Claude.md opened" with title "Cozy"'
                ;;
            j)
                open "/Users/inkling/.claude/settings.json"
                osascript -e 'display notification "Settings.json opened" with title "Cozy"'
                ;;
            u)
                run_in_new_terminal "npm install -g @anthropic-ai/claude-code@latest" "Claude Code 升级"
                osascript -e 'display notification "Claude Code update started" with title "Cozy"'
                ;;
            i)
                open "/Users/inkling/Desktop/CoreInject/秋城落叶_启动.command"
                osascript -e 'display notification "Core Inject started" with title "Cozy"'
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
            b)
                if check_wrangler; then
                    upload_to_r2
                else
                    osascript -e 'display notification "Wrangler not found" with title "Cozy"'
                fi
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
            *)
                ;;
        esac
    done
}

# 启动主程序
main_loop