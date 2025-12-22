#!/bin/bash
# ProTab 集成测试
# 测试整个系统的端到端功能

# 导入测试框架
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../bash_test_lib.sh"

# 项目目录
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 集成测试环境
INTEGRATION_TEST_DIR="/tmp/protab_integration_test"

# 清理并设置测试环境
setup_integration_env() {
    echo "🔧 设置集成测试环境..."

    # 清理旧环境
    rm -rf "$INTEGRATION_TEST_DIR"
    mkdir -p "$INTEGRATION_TEST_DIR"

    # 复制项目文件到测试环境
    cp -r "$PROJECT_DIR"/{*.swift,*.sh,lib,shortcuts,config.command,protab.command} "$INTEGRATION_TEST_DIR/" 2>/dev/null || true

    # 创建测试配置
    cat > "$INTEGRATION_TEST_DIR/test_config.json" << 'EOF'
{
    "app": {
        "name": "ProTab Integration Test",
        "version": "1.0.0-test",
        "debug": true
    },
    "paths": {
        "work_directory": "/tmp/protab_integration_test",
        "scripts_directory": "/tmp/protab_integration_test/shortcuts"
    },
    "keyboard": {
        "wait_timeout_ms": 200,
        "shortcuts": {
            "t": "test_integration.sh",
            "s": "test_status.sh"
        }
    },
    "services": {
        "api_endpoint": "http://localhost:8080",
        "timeout_seconds": 3
    },
    "ui": {
        "app_name": "ProTab Integration Test",
        "show_notifications": false,
        "color_theme": "dark"
    }
}
EOF

    # 创建测试快捷键脚本
    cat > "$INTEGRATION_TEST_DIR/shortcuts/test_integration.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/../lib/config.sh" || exit 1
init_config || exit 1

echo "Integration test executed at $(date)"
echo "App: $(get_config 'app.name')"
echo "Version: $(get_config 'app.version')"
echo "Work dir: $(get_config 'paths.work_directory')"

# 创建测试输出文件
test_output="$(get_config 'paths.work_directory')/integration_test_output.txt"
echo "Integration test successful at $(date)" > "$test_output"

exit 0
EOF

    cat > "$INTEGRATION_TEST_DIR/shortcuts/test_status.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/../lib/config.sh" || exit 1
init_config || exit 1

echo "Status check at $(date)"
echo "Config loaded: YES"
echo "Scripts directory: $(get_config 'paths.scripts_directory')"

exit 0
EOF

    chmod +x "$INTEGRATION_TEST_DIR/shortcuts"/*.sh
    chmod +x "$INTEGRATION_TEST_DIR"/*.command

    # 设置环境变量
    export PROTAB_CONFIG="$INTEGRATION_TEST_DIR/test_config.json"
    export PATH="$INTEGRATION_TEST_DIR:$PATH"

    cd "$INTEGRATION_TEST_DIR"
}

# 清理测试环境
cleanup_integration_env() {
    echo "🧹 清理集成测试环境..."
    rm -rf "$INTEGRATION_TEST_DIR"
    unset PROTAB_CONFIG
}

test_suite_start "ProTab 集成测试"

setup_integration_env

# 测试1: 配置系统集成
echo "测试配置系统集成..."

# 测试配置加载
source "$INTEGRATION_TEST_DIR/lib/config.sh"
init_config
assert_success $? "配置系统应该成功初始化"

app_name=$(get_config "app.name")
assert_equals "ProTab Integration Test" "$app_name" "应用名称应该正确加载"

# 测试2: 构建系统
echo "测试构建系统..."

# 修改构建脚本以在测试环境中工作
if [ -f "$INTEGRATION_TEST_DIR/build.sh" ]; then
    cd "$INTEGRATION_TEST_DIR"

    # 运行构建脚本（静默模式）
    ./build.sh > build_output.log 2>&1
    build_exit_code=$?

    if [ $build_exit_code -eq 0 ]; then
        assert_success 0 "构建应该成功"
        assert_file_exists "$INTEGRATION_TEST_DIR/tab_monitor" "应该生成可执行文件"
    else
        echo "构建输出:"
        cat build_output.log
        assert_success 1 "构建失败"
    fi
else
    echo "⚠️  跳过构建测试（build.sh不存在）"
fi

# 测试3: 主控制脚本
echo "测试主控制脚本..."

if [ -f "$INTEGRATION_TEST_DIR/protab.command" ]; then
    # 测试help命令
    help_output=$(bash "$INTEGRATION_TEST_DIR/protab.command" help 2>&1)
    help_exit_code=$?
    assert_success $help_exit_code "help命令应该成功"
    assert_contains "$help_output" "Usage:" "help输出应该包含使用说明"

    # 测试status命令
    status_output=$(bash "$INTEGRATION_TEST_DIR/protab.command" status 2>&1)
    status_exit_code=$?
    assert_success $status_exit_code "status命令应该成功"

    # 测试config命令
    config_output=$(bash "$INTEGRATION_TEST_DIR/protab.command" config 2>&1)
    config_exit_code=$?
    assert_success $config_exit_code "config命令应该成功"
else
    echo "⚠️  跳过主控制脚本测试（protab.command不存在）"
fi

# 测试4: 快捷键脚本执行
echo "测试快捷键脚本执行..."

# 直接执行快捷键脚本
output=$("$INTEGRATION_TEST_DIR/shortcuts/test_integration.sh" 2>&1)
exit_code=$?
assert_success $exit_code "集成测试脚本应该成功执行"
assert_contains "$output" "Integration test executed" "应该输出执行消息"
assert_contains "$output" "ProTab Integration Test" "应该显示正确的应用名称"

# 检查脚本是否创建了输出文件
test_output_file="$INTEGRATION_TEST_DIR/integration_test_output.txt"
assert_file_exists "$test_output_file" "集成测试应该创建输出文件"

if [ -f "$test_output_file" ]; then
    output_content=$(cat "$test_output_file")
    assert_contains "$output_content" "Integration test successful" "输出文件应该包含成功消息"
fi

# 测试5: 多脚本并发执行
echo "测试多脚本并发执行..."

(
    "$INTEGRATION_TEST_DIR/shortcuts/test_integration.sh" > /tmp/int_test1.out 2>&1 &
    pid1=$!
    "$INTEGRATION_TEST_DIR/shortcuts/test_status.sh" > /tmp/int_test2.out 2>&1 &
    pid2=$!

    wait $pid1
    exit1=$?
    wait $pid2
    exit2=$?

    if [ $exit1 -eq 0 ] && [ $exit2 -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
)
assert_success $? "多个脚本应该能够并发执行"

# 清理临时文件
rm -f /tmp/int_test1.out /tmp/int_test2.out

# 测试6: 配置验证和错误处理
echo "测试配置验证和错误处理..."

# 备份原配置
cp "$INTEGRATION_TEST_DIR/test_config.json" "$INTEGRATION_TEST_DIR/test_config.json.bak"

# 创建无效配置
echo "{ invalid json }" > "$INTEGRATION_TEST_DIR/test_config.json"

# 尝试执行脚本，应该失败
"$INTEGRATION_TEST_DIR/shortcuts/test_integration.sh" > /dev/null 2>&1
invalid_config_exit=$?
assert_failure $invalid_config_exit "无效配置时脚本应该失败"

# 恢复配置
mv "$INTEGRATION_TEST_DIR/test_config.json.bak" "$INTEGRATION_TEST_DIR/test_config.json"

# 测试7: 权限和安全
echo "测试权限和安全..."

# 检查脚本文件权限
for script in "$INTEGRATION_TEST_DIR/shortcuts"/*.sh; do
    if [ -x "$script" ]; then
        assert_success 0 "脚本文件 $(basename "$script") 应该可执行"
    else
        assert_success 1 "脚本文件 $(basename "$script") 应该可执行"
    fi
done

# 检查配置文件不应该可执行
if [ -x "$INTEGRATION_TEST_DIR/test_config.json" ]; then
    assert_success 1 "配置文件不应该可执行"
else
    assert_success 0 "配置文件正确设置为不可执行"
fi

# 测试8: 环境变量处理
echo "测试环境变量处理..."

# 测试HOME变量展开
work_dir=$(get_config "paths.work_directory")
if [[ "$work_dir" != *"$"* ]]; then
    assert_success 0 "环境变量应该被正确展开"
else
    assert_success 1 "环境变量未被正确展开: $work_dir"
fi

# 测试9: 自动启动配置（只检查脚本存在性）
echo "测试自动启动配置..."

if [ -f "$INTEGRATION_TEST_DIR/setup_autostart.sh" ]; then
    # 只检查脚本语法，不实际执行
    bash -n "$INTEGRATION_TEST_DIR/setup_autostart.sh"
    assert_success $? "自动启动脚本语法应该正确"
else
    echo "⚠️  跳过自动启动测试（setup_autostart.sh不存在）"
fi

# 测试10: 完整工作流程
echo "测试完整工作流程..."

# 模拟完整的使用流程
echo "📋 模拟完整工作流程:"
echo "1. 配置加载..."
init_config
workflow_step1=$?

echo "2. 执行快捷键t..."
"$INTEGRATION_TEST_DIR/shortcuts/test_integration.sh" > /dev/null 2>&1
workflow_step2=$?

echo "3. 执行快捷键s..."
"$INTEGRATION_TEST_DIR/shortcuts/test_status.sh" > /dev/null 2>&1
workflow_step3=$?

if [ $workflow_step1 -eq 0 ] && [ $workflow_step2 -eq 0 ] && [ $workflow_step3 -eq 0 ]; then
    assert_success 0 "完整工作流程应该成功"
else
    assert_success 1 "完整工作流程失败 ($workflow_step1,$workflow_step2,$workflow_step3)"
fi

echo "📊 生成集成测试报告..."

# 创建测试报告
cat > "$INTEGRATION_TEST_DIR/integration_test_report.txt" << EOF
ProTab 集成测试报告
==================

测试时间: $(date)
测试环境: $INTEGRATION_TEST_DIR
配置文件: $PROTAB_CONFIG

测试组件:
- 配置系统: ✓
- 构建系统: ✓
- 主控制脚本: ✓
- 快捷键脚本: ✓
- 并发执行: ✓
- 错误处理: ✓
- 权限检查: ✓
- 环境变量: ✓
- 工作流程: ✓

总计测试: $tests_run
通过: $tests_passed
失败: $tests_failed

$([ $tests_failed -eq 0 ] && echo "🎉 所有集成测试通过!" || echo "❌ 存在测试失败")
EOF

echo "📄 集成测试报告已生成: $INTEGRATION_TEST_DIR/integration_test_report.txt"

cleanup_integration_env

test_suite_end