#!/bin/bash
# 切换 macOS 系统 VPN 开关
# 支持系统设置中配置的 VPN 服务

# 获取脚本所在目录的父目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 获取当前 VPN 列表和状态
get_vpn_status() {
    scutil --nc list 2>/dev/null
}

# 获取第一个可用的 VPN 服务名称
get_first_vpn_name() {
    scutil --nc list 2>/dev/null | grep -E "^\*.*VPN" | head -1 | sed -E 's/.*"([^"]+)".*/\1/'
}

# 获取 VPN 连接状态
is_vpn_connected() {
    local vpn_name="$1"
    scutil --nc status "$vpn_name" 2>/dev/null | head -1 | grep -q "Connected"
}

# 连接 VPN
connect_vpn() {
    local vpn_name="$1"
    scutil --nc start "$vpn_name" 2>/dev/null
}

# 断开 VPN
disconnect_vpn() {
    local vpn_name="$1"
    scutil --nc stop "$vpn_name" 2>/dev/null
}

# 主逻辑
main() {
    # 获取 VPN 名称（可以从参数传入，或使用第一个可用的）
    local vpn_name="${1:-$(get_first_vpn_name)}"
    
    if [ -z "$vpn_name" ]; then
        osascript -e 'display notification "未找到任何 VPN 配置" with title "ProTab - VPN"'
        echo "未找到任何 VPN 配置"
        exit 1
    fi
    
    # 检查当前状态并切换
    if is_vpn_connected "$vpn_name"; then
        # 当前已连接，断开
        disconnect_vpn "$vpn_name"
        sleep 1
        
        # 验证断开状态
        if is_vpn_connected "$vpn_name"; then
            osascript -e "display notification \"$vpn_name 断开失败\" with title \"ProTab - VPN\""
            echo "VPN 断开失败: $vpn_name"
        else
            osascript -e "display notification \"$vpn_name 已断开\" with title \"ProTab - VPN\""
            echo "VPN 已断开: $vpn_name"
        fi
    else
        # 当前未连接，连接
        connect_vpn "$vpn_name"
        sleep 2
        
        # 验证连接状态
        if is_vpn_connected "$vpn_name"; then
            osascript -e "display notification \"$vpn_name 已连接\" with title \"ProTab - VPN\""
            echo "VPN 已连接: $vpn_name"
        else
            osascript -e "display notification \"$vpn_name 连接中...\" with title \"ProTab - VPN\""
            echo "VPN 连接中: $vpn_name"
        fi
    fi
}

main "$@"
