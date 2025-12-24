#!/bin/bash
# 快捷键清理内存脚本 - 使用 Rust 版本

# 获取脚本所在目录的父目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 检查 Rust 版本是否存在，否则使用系统 purge
RUST_BINARY="$PROJECT_DIR/rust/target/release/freeup_ram_rust"

# 检查是否请求强制清理模式
if [[ "$1" == "--force" ]]; then
    echo "使用强制清理模式..."

    if [ -f "$RUST_BINARY" ]; then
        # 连续清理多次以获得更好效果
        echo "执行第1轮清理..."
        result1=$("$RUST_BINARY" 2>&1 | tail -1)
        sleep 1

        echo "执行第2轮清理..."
        result2=$("$RUST_BINARY" 2>&1 | tail -1)
        sleep 1

        echo "执行第3轮清理..."
        result3=$("$RUST_BINARY" 2>&1 | tail -1)

        # 显示最后一轮的结果
        result="$result3"
    else
        echo "强制系统内存清理"
        sudo purge
        sleep 1
        sudo purge
        result="强制清理完成"
    fi
else
    # 普通清理模式
    if [ -f "$RUST_BINARY" ]; then
        echo "使用 Rust 内存清理器"
        result=$("$RUST_BINARY" 2>&1 | tail -1)
    else
        echo "使用系统内存清理"
        if sudo purge 2>/dev/null; then
            result="finished.(系统清理完成)"
        else
            result="内存清理失败"
        fi
    fi
fi

# 显示通知
if [[ "$result" == *"finished."* ]]; then
    osascript -e "display notification \"$result\" with title \"ProTab - 内存清理\""
else
    osascript -e "display notification \"$result\" with title \"ProTab - 内存状态\""
fi

echo "$result"