#!/bin/bash
# ProTab 自动启动配置脚本

# 导入配置库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh" || {
    echo "Error: Cannot load configuration library"
    exit 1
}

echo "Setting up ProTab auto-start..."

# 初始化配置
if ! init_config; then
    echo "Error: Failed to initialize configuration"
    echo "Please run configuration setup first: ./config.command"
    exit 1
fi

# 获取配置值
WORK_DIR=$(get_config "paths.work_directory")
APP_NAME=$(get_config "ui.app_name")
PROTAB_PATH="$WORK_DIR/protab.command"

# 创建plist文件路径
PLIST_PATH="$HOME/Library/LaunchAgents/com.protab.startup.plist"

# 验证路径
if [ ! -f "$PROTAB_PATH" ]; then
    echo "Error: ProTab executable not found: $PROTAB_PATH"
    exit 1
fi

# 创建LaunchAgent plist文件
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.protab.startup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$PROTAB_PATH</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PROTAB_CONFIG</key>
        <string>$CONFIG_FILE</string>
    </dict>
</dict>
</plist>
EOF

# 加载LaunchAgent
launchctl load "$PLIST_PATH" 2>/dev/null

echo "✅ $APP_NAME auto-start configured"
echo "📍 Location: $PLIST_PATH"
echo "🔄 Will start automatically on next login"
echo ""
echo "To disable auto-start, run:"
echo "launchctl unload $PLIST_PATH && rm $PLIST_PATH"