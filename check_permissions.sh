#!/bin/bash
# ProTab 权限检查和修复工具

echo "=== ProTab 权限检查工具 ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB_MONITOR="$SCRIPT_DIR/tab_monitor"

# 检查tab_monitor是否存在
if [ ! -f "$TAB_MONITOR" ]; then
    echo "❌ 找不到 tab_monitor"
    echo "   请先运行: ./build.sh"
    exit 1
fi

echo "✅ tab_monitor 路径: $TAB_MONITOR"
echo ""

# 检查是否有辅助功能权限
echo "正在检查辅助功能权限..."
if "$TAB_MONITOR" 2>&1 | grep -q "需要辅助功能权限"; then
    echo "❌ 没有辅助功能权限"
    echo ""
    echo "请按以下步骤操作："
    echo "1. 打开 系统设置 > 隐私与安全性 > 辅助功能"
    echo "2. 点击 + 按钮"
    echo "3. 选择以下文件："
    echo "   $TAB_MONITOR"
    echo "4. 重新运行此脚本验证"
    echo ""
    
    # 尝试打开系统设置
    osascript -e 'tell application "System Settings" to activate' -e 'do shell script "open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\""' 2>/dev/null
    
    exit 1
else
    echo "✅ 辅助功能权限已授予"
fi

echo ""
echo "=== 权限检查完成 ==="
echo "现在可以运行 ./protab.command 启动 ProTab"
