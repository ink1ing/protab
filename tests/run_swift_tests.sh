#!/bin/bash
# Swift 测试运行脚本

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 运行 Swift 单元测试..."
echo "项目目录: $PROJECT_DIR"

# 检查 Swift 编译器
if ! command -v swiftc &> /dev/null; then
    echo "❌ 错误: 未找到 Swift 编译器"
    echo "请安装 Xcode Command Line Tools"
    exit 1
fi

cd "$PROJECT_DIR"

# 创建临时测试目录
TEST_BUILD_DIR="./tests/build"
mkdir -p "$TEST_BUILD_DIR"

echo "📦 编译测试..."

# 编译源代码和测试代码一起
swiftc -o "$TEST_BUILD_DIR/ProTabConfigTests" \
    ProTabConfig.swift \
    tab_monitor.swift \
    tests/swift/ProTabConfigTests.swift \
    -framework XCTest \
    -framework Foundation \
    -framework Cocoa \
    -framework Carbon

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功"
echo "🏃 运行测试..."

# 运行测试
"$TEST_BUILD_DIR/ProTabConfigTests"

if [ $? -eq 0 ]; then
    echo "✅ 所有 Swift 测试通过"
else
    echo "❌ 某些 Swift 测试失败"
    exit 1
fi

# 清理
echo "🧹 清理临时文件..."
rm -rf "$TEST_BUILD_DIR"

echo "🎉 Swift 测试完成"