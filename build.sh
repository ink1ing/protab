#!/bin/bash
# ProTab 编译脚本
# 编译 Swift 文件为可执行程序

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 检查 Swift 编译器
if ! command -v swiftc &> /dev/null; then
    echo "Error: Swift compiler not found"
    echo "Please install Xcode Command Line Tools"
    exit 1
fi

echo "Compiling ProTab..."

# 编译 Swift 文件
swiftc swift/ProTabConfig.swift swift/tab_monitor.swift swift/main.swift -o tab_monitor 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful"
    echo "Executable created: ./tab_monitor"

    # 设置执行权限
    chmod +x tab_monitor

    echo
    echo "To run: ./tab_monitor"
else
    echo "❌ Compilation failed"
    exit 1
fi