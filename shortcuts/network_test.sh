#!/bin/bash
# 快捷键网络测试脚本


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

# 测试中国网络连通性
cn_status="❌"
if curl -s --max-time 3 --connect-timeout 2 "https://www.gov.cn" > /dev/null 2>&1 && \
   curl -s --max-time 3 --connect-timeout 2 "https://www.aliyun.com" > /dev/null 2>&1 && \
   ping -c 1 -W 2000 114.114.114.114 > /dev/null 2>&1; then
    cn_status="✅"
fi

# 测试国际网络连通性
global_status="❌"
if curl -s --max-time 3 --connect-timeout 2 "https://www.cloudflare.com" > /dev/null 2>&1 && \
   curl -s --max-time 3 --connect-timeout 2 "https://www.apple.com" > /dev/null 2>&1 && \
   (ping -c 1 -W 2000 1.1.1.1 > /dev/null 2>&1 || ping -c 1 -W 2000 8.8.8.8 > /dev/null 2>&1); then
    global_status="✅"
fi

# 获取IP地址
ip_addr=$(curl -s --max-time 3 --connect-timeout 2 "https://ifconfig.me" 2>/dev/null | head -1)
if [ -n "$ip_addr" ]; then
    ip_result="IP: ${ip_addr}"
else
    ip_result="IP: unknown"
fi

# 显示通知
osascript -e "display notification \"CN: ${cn_status} Global: ${global_status} ${ip_result}\" with title \"Network Test\""