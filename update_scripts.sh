#!/bin/bash
# 批量更新 ProTab shell 脚本以使用配置系统

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHORTCUTS_DIR="$SCRIPT_DIR/shortcuts"

echo "Updating ProTab shell scripts to use configuration system..."

# 通用配置导入代码
CONFIG_IMPORT='# 导入配置库
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
EDITOR_APP=$(get_config "ui.editor_app")'

# 更新所有需要工作目录的脚本
update_work_dir_scripts() {
    local scripts=("clean_ram.sh" "upload_to_r2.sh" "auth_api.sh" "start_core_inject.sh")

    for script in "${scripts[@]}"; do
        if [ -f "$SHORTCUTS_DIR/$script" ]; then
            echo "Updating $script..."

            # 备份原文件
            cp "$SHORTCUTS_DIR/$script" "$SHORTCUTS_DIR/$script.bak"

            # 添加配置导入
            {
                head -3 "$SHORTCUTS_DIR/$script"
                echo
                echo "$CONFIG_IMPORT"
                echo
                echo "# 切换到工作目录"
                echo 'if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then'
                echo '    cd "$WORK_DIR"'
                echo 'else'
                echo '    echo "Error: Work directory not found: $WORK_DIR" >&2'
                echo '    exit 1'
                echo 'fi'
                echo
                tail -n +5 "$SHORTCUTS_DIR/$script" | sed 's|/Users/inkling/Desktop/cozy proj|$WORK_DIR|g'
            } > "$SHORTCUTS_DIR/$script.tmp"

            mv "$SHORTCUTS_DIR/$script.tmp" "$SHORTCUTS_DIR/$script"
            chmod +x "$SHORTCUTS_DIR/$script"
        fi
    done
}

# 更新 Claude 相关脚本
update_claude_scripts() {
    local scripts=("edit_claude_md.sh" "edit_settings_json.sh")

    for script in "${scripts[@]}"; do
        if [ -f "$SHORTCUTS_DIR/$script" ]; then
            echo "Updating $script..."

            # 备份原文件
            cp "$SHORTCUTS_DIR/$script" "$SHORTCUTS_DIR/$script.bak"

            case "$script" in
                "edit_claude_md.sh")
                    {
                        echo '#!/bin/bash'
                        echo '# Tab+M - 编辑 Claude 配置'
                        echo
                        echo "$CONFIG_IMPORT"
                        echo
                        echo 'osascript -e "tell application \"$EDITOR_APP\" to open POSIX file \"$CLAUDE_DIR/CLAUDE.md\""'
                    } > "$SHORTCUTS_DIR/$script"
                    ;;
                "edit_settings_json.sh")
                    {
                        echo '#!/bin/bash'
                        echo '# Tab+J - 编辑 Claude 设置'
                        echo
                        echo "$CONFIG_IMPORT"
                        echo
                        echo 'osascript -e "tell application \"$EDITOR_APP\" to open POSIX file \"$CLAUDE_DIR/settings.json\""'
                    } > "$SHORTCUTS_DIR/$script"
                    ;;
            esac

            chmod +x "$SHORTCUTS_DIR/$script"
        fi
    done
}

# 更新其他脚本
update_other_scripts() {
    local scripts=("new_terminal.sh" "new_private_tab.sh" "new_claude_code.sh" "update_claude_code.sh" "open_force_quit.sh" "screenshot.sh" "record.sh" "network_test.sh")

    for script in "${scripts[@]}"; do
        if [ -f "$SHORTCUTS_DIR/$script" ]; then
            echo "Updating $script..."

            # 备份原文件
            cp "$SHORTCUTS_DIR/$script" "$SHORTCUTS_DIR/$script.bak"

            # 只添加配置导入，保持原有逻辑
            {
                head -3 "$SHORTCUTS_DIR/$script"
                echo
                echo "$CONFIG_IMPORT"
                echo
                tail -n +4 "$SHORTCUTS_DIR/$script" | sed 's/"Cozy"/"$APP_NAME"/g'
            } > "$SHORTCUTS_DIR/$script.tmp"

            mv "$SHORTCUTS_DIR/$script.tmp" "$SHORTCUTS_DIR/$script"
            chmod +x "$SHORTCUTS_DIR/$script"
        fi
    done
}

# 执行更新
update_work_dir_scripts
update_claude_scripts
update_other_scripts

echo
echo "✅ Shell scripts updated successfully!"
echo
echo "Backup files created with .bak extension"
echo "To test configuration system:"
echo "  1. Run: ./config.command"
echo "  2. Choose 'First-time setup'"
echo "  3. Test shortcuts with: ./build.sh && ./tab_monitor"