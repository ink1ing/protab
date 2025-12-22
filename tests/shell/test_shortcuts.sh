#!/bin/bash
# 快捷键脚本功能测试

# 导入测试框架
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../bash_test_lib.sh"

# 项目目录
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 测试环境目录
TEST_ENV_DIR="/tmp/protab_shortcuts_test"
mkdir -p "$TEST_ENV_DIR/shortcuts"

# 设置测试配置
setup_test_env() {
    # 创建测试配置
    cat > "$TEST_ENV_DIR/test_config.json" << 'EOF'
{
    "app": {
        "name": "ProTab Test",
        "debug": true
    },
    "paths": {
        "work_directory": "/tmp/protab_shortcuts_test",
        "scripts_directory": "/tmp/protab_shortcuts_test/shortcuts"
    },
    "services": {
        "api_endpoint": "http://localhost:8080",
        "timeout_seconds": 5
    }
}
EOF

    # 复制配置库
    cp "$PROJECT_DIR/lib/config.sh" "$TEST_ENV_DIR/"

    # 设置环境变量
    export PROTAB_CONFIG="$TEST_ENV_DIR/test_config.json"
    export PATH="$TEST_ENV_DIR:$PATH"

    # 创建测试快捷键脚本
    create_test_shortcuts
}

# 创建测试快捷键脚本
create_test_shortcuts() {
    # 创建一个简单的测试脚本
    cat > "$TEST_ENV_DIR/shortcuts/test_simple.sh" << 'EOF'
#!/bin/bash
# 简单测试脚本
source "$(dirname "$0")/../config.sh" || exit 1
init_config || exit 1

echo "Test script executed"
echo "Work dir: $(get_config 'paths.work_directory')"
exit 0
EOF
    chmod +x "$TEST_ENV_DIR/shortcuts/test_simple.sh"

    # 创建一个需要网络的测试脚本
    cat > "$TEST_ENV_DIR/shortcuts/test_network.sh" << 'EOF'
#!/bin/bash
# 网络测试脚本
source "$(dirname "$0")/../config.sh" || exit 1
init_config || exit 1

api_endpoint=$(get_config "services.api_endpoint")
timeout_seconds=$(get_config "services.timeout_seconds")

echo "Testing network connectivity..."
echo "API endpoint: $api_endpoint"
echo "Timeout: $timeout_seconds seconds"

# 测试网络连接（使用本地回环，总是会成功）
if curl -s --max-time "$timeout_seconds" http://localhost:80 >/dev/null 2>&1; then
    echo "Network test passed"
    exit 0
else
    echo "Network test failed"
    exit 1
fi
EOF
    chmod +x "$TEST_ENV_DIR/shortcuts/test_network.sh"

    # 创建一个文件操作脚本
    cat > "$TEST_ENV_DIR/shortcuts/test_file_ops.sh" << 'EOF'
#!/bin/bash
# 文件操作测试脚本
source "$(dirname "$0")/../config.sh" || exit 1
init_config || exit 1

work_dir=$(get_config "paths.work_directory")
test_file="$work_dir/test_output.txt"

echo "Creating test file: $test_file"
echo "Test content $(date)" > "$test_file"

if [ -f "$test_file" ]; then
    echo "File creation successful"
    rm "$test_file"  # 清理
    exit 0
else
    echo "File creation failed"
    exit 1
fi
EOF
    chmod +x "$TEST_ENV_DIR/shortcuts/test_file_ops.sh"

    # 创建一个故意失败的脚本
    cat > "$TEST_ENV_DIR/shortcuts/test_failure.sh" << 'EOF'
#!/bin/bash
# 失败测试脚本
echo "This script is designed to fail"
exit 1
EOF
    chmod +x "$TEST_ENV_DIR/shortcuts/test_failure.sh"
}

# 清理测试环境
cleanup_test_env() {
    rm -rf "$TEST_ENV_DIR"
    unset PROTAB_CONFIG
}

test_suite_start "快捷键脚本功能测试"

setup_test_env

# 测试脚本存在性
echo "测试脚本文件存在性..."
assert_file_exists "$TEST_ENV_DIR/shortcuts/test_simple.sh" "简单测试脚本应该存在"
assert_file_exists "$TEST_ENV_DIR/shortcuts/test_network.sh" "网络测试脚本应该存在"
assert_file_exists "$TEST_ENV_DIR/shortcuts/test_file_ops.sh" "文件操作脚本应该存在"
assert_file_exists "$TEST_ENV_DIR/shortcuts/test_failure.sh" "失败测试脚本应该存在"

# 测试脚本权限
echo "测试脚本执行权限..."
if [ -x "$TEST_ENV_DIR/shortcuts/test_simple.sh" ]; then
    assert_success 0 "简单测试脚本应该可执行"
else
    assert_success 1 "简单测试脚本应该可执行"
fi

# 测试简单脚本执行
echo "测试简单脚本执行..."
output=$("$TEST_ENV_DIR/shortcuts/test_simple.sh" 2>&1)
exit_code=$?
assert_success $exit_code "简单测试脚本应该成功执行"
assert_contains "$output" "Test script executed" "输出应包含执行消息"
assert_contains "$output" "/tmp/protab_shortcuts_test" "输出应包含工作目录"

# 测试文件操作脚本
echo "测试文件操作脚本..."
output=$("$TEST_ENV_DIR/shortcuts/test_file_ops.sh" 2>&1)
exit_code=$?
assert_success $exit_code "文件操作脚本应该成功执行"
assert_contains "$output" "File creation successful" "应该成功创建文件"

# 测试失败脚本处理
echo "测试失败脚本处理..."
output=$("$TEST_ENV_DIR/shortcuts/test_failure.sh" 2>&1)
exit_code=$?
assert_failure $exit_code "失败脚本应该返回非零退出码"
assert_contains "$output" "This script is designed to fail" "应该输出失败消息"

# 测试网络脚本（可能会失败，这是正常的）
echo "测试网络脚本..."
output=$("$TEST_ENV_DIR/shortcuts/test_network.sh" 2>&1)
exit_code=$?
# 网络测试可能成功也可能失败，我们只检查是否有输出
assert_contains "$output" "Testing network connectivity" "应该输出网络测试消息"
assert_contains "$output" "API endpoint:" "应该显示API端点"

# 测试配置加载错误处理
echo "测试配置加载错误处理..."
# 临时破坏配置
mv "$TEST_ENV_DIR/test_config.json" "$TEST_ENV_DIR/test_config.json.bak"

output=$("$TEST_ENV_DIR/shortcuts/test_simple.sh" 2>&1)
exit_code=$?
assert_failure $exit_code "缺少配置文件时脚本应该失败"

# 恢复配置
mv "$TEST_ENV_DIR/test_config.json.bak" "$TEST_ENV_DIR/test_config.json"

# 测试脚本模板完整性
echo "测试脚本模板完整性..."
for script in "$TEST_ENV_DIR/shortcuts"/*.sh; do
    if grep -q "source.*config.sh" "$script" && grep -q "init_config" "$script"; then
        assert_success 0 "脚本 $(basename "$script") 包含正确的配置加载"
    else
        assert_success 1 "脚本 $(basename "$script") 应该包含配置加载"
    fi
done

# 测试脚本并行执行（简单测试）
echo "测试脚本并行执行..."
(
    "$TEST_ENV_DIR/shortcuts/test_simple.sh" > /tmp/test1.out 2>&1 &
    pid1=$!
    "$TEST_ENV_DIR/shortcuts/test_file_ops.sh" > /tmp/test2.out 2>&1 &
    pid2=$!

    wait $pid1
    exit1=$?
    wait $pid2
    exit2=$?

    if [ $exit1 -eq 0 ] && [ $exit2 -eq 0 ]; then
        echo "并行执行成功"
        exit 0
    else
        echo "并行执行失败: $exit1, $exit2"
        exit 1
    fi
)
assert_success $? "脚本应该能够并行执行"

# 清理临时文件
rm -f /tmp/test1.out /tmp/test2.out

cleanup_test_env

test_suite_end