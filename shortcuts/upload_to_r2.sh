#!/bin/bash
# Tab+B - 上传到R2


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

# 切换到工作目录
if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    cd "$WORK_DIR"
else
    echo "Error: Work directory not found: $WORK_DIR" >&2
    exit 1
fi


# 检查wrangler
if ! command -v wrangler &> /dev/null; then
    osascript -e 'display notification "Wrangler not found" with title "Cozy"'
    exit 1
fi

# 直接执行上传逻辑，而不是source整个文件
bucket_name="r2"

# 使用AppleScript打开文件选择器
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
    osascript -e 'display notification "Upload cancelled" with title "Cozy"'
    exit 1
fi

# 提取原始文件名和扩展名
original_filename=$(basename "$selected_file")
extension="${original_filename##*.}"

# 获取自定义文件名
custom_name=$(osascript -e 'try
    display dialog "Name file (leave blank to keep original):" default answer "" with title "Cozy Upload"
    text returned of result
end try' 2>/dev/null)

# 确定最终文件名
if [ -n "$custom_name" ]; then
    final_filename="${custom_name}.${extension}"
else
    final_filename="$original_filename"
fi

# 执行上传
upload_result=$(wrangler r2 object put "$bucket_name/$final_filename" --file="$selected_file" --remote 2>&1)
upload_exit_code=$?

if [ $upload_exit_code -eq 0 ]; then
    osascript -e "display notification \"✅ Upload success: $final_filename\" with title \"Cozy\""
else
    osascript -e "display notification \"❌ Upload failed\" with title \"Cozy\""
fi