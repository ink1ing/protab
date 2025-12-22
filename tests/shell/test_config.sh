#!/bin/bash
# 配置管理库测试

# 导入测试框架
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../bash_test_lib.sh"

# 导入被测试的库
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_DIR/lib/config.sh"

# 测试数据目录
TEST_DATA_DIR="/tmp/protab_config_test"
mkdir -p "$TEST_DATA_DIR"

# 清理函数
cleanup() {
    rm -rf "$TEST_DATA_DIR"
    unset PROTAB_CONFIG
    unset HOME_ORIGINAL
}

# 设置测试环境
setup() {
    # 保存原始HOME变量
    HOME_ORIGINAL="$HOME"
    export HOME="$TEST_DATA_DIR"

    # 创建测试配置文件
    cat > "$TEST_DATA_DIR/test_config.json" << 'EOF'
{
    "app": {
        "name": "ProTab Test",
        "version": "1.0.0",
        "debug": true
    },
    "paths": {
        "work_directory": "${HOME}/protab_work",
        "scripts_directory": "${HOME}/protab_work/shortcuts"
    },
    "keyboard": {
        "wait_timeout_ms": 500,
        "shortcuts": {
            "t": "test.sh",
            "a": "auth.sh"
        }
    },
    "services": {
        "api_endpoint": "http://localhost:8080",
        "timeout_seconds": 10
    },
    "ui": {
        "app_name": "ProTab Test UI",
        "show_notifications": false
    }
}
EOF

    export PROTAB_CONFIG="$TEST_DATA_DIR/test_config.json"
}

# 恢复环境
teardown() {
    export HOME="$HOME_ORIGINAL"
    cleanup
}

test_suite_start "配置管理库测试"

setup

# 测试配置初始化
echo "测试配置初始化..."
init_config
assert_success $? "配置初始化应该成功"

# 测试基本配置读取
echo "测试基本配置读取..."
app_name=$(get_config "app.name")
assert_equals "ProTab Test" "$app_name" "应用名称读取正确"

app_version=$(get_config "app.version")
assert_equals "1.0.0" "$app_version" "应用版本读取正确"

debug_mode=$(get_config "app.debug")
assert_equals "true" "$debug_mode" "调试模式读取正确"

# 测试环境变量展开
echo "测试环境变量展开..."
work_dir=$(get_config "paths.work_directory")
expected_work_dir="$TEST_DATA_DIR/protab_work"
assert_equals "$expected_work_dir" "$work_dir" "工作目录环境变量展开正确"

scripts_dir=$(get_config "paths.scripts_directory")
expected_scripts_dir="$TEST_DATA_DIR/protab_work/shortcuts"
assert_equals "$expected_scripts_dir" "$scripts_dir" "脚本目录环境变量展开正确"

# 测试嵌套配置读取
echo "测试嵌套配置读取..."
timeout_ms=$(get_config "keyboard.wait_timeout_ms")
assert_equals "500" "$timeout_ms" "等待超时时间读取正确"

api_endpoint=$(get_config "services.api_endpoint")
assert_equals "http://localhost:8080" "$api_endpoint" "API端点读取正确"

# 测试快捷键配置读取
echo "测试快捷键配置读取..."
shortcut_t=$(get_config "keyboard.shortcuts.t")
assert_equals "test.sh" "$shortcut_t" "快捷键t配置读取正确"

shortcut_a=$(get_config "keyboard.shortcuts.a")
assert_equals "auth.sh" "$shortcut_a" "快捷键a配置读取正确"

# 测试不存在的配置键
echo "测试不存在的配置键..."
nonexistent=$(get_config "nonexistent.key")
assert_equals "" "$nonexistent" "不存在的配置键应返回空值"

# 测试配置验证
echo "测试配置验证..."
validate_config
assert_success $? "有效配置应通过验证"

# 测试无效配置文件
echo "测试无效配置文件..."
invalid_config="$TEST_DATA_DIR/invalid_config.json"
echo "{ invalid json" > "$invalid_config"
export PROTAB_CONFIG="$invalid_config"

init_config
assert_failure $? "无效JSON配置应导致初始化失败"

# 测试不存在的配置文件
echo "测试不存在的配置文件..."
export PROTAB_CONFIG="/tmp/nonexistent_config.json"
init_config
assert_failure $? "不存在的配置文件应导致初始化失败"

# 测试配置文件权限
echo "测试配置文件权限..."
setup  # 重新设置有效配置

readonly_config="$TEST_DATA_DIR/readonly_config.json"
cp "$TEST_DATA_DIR/test_config.json" "$readonly_config"
chmod 000 "$readonly_config"
export PROTAB_CONFIG="$readonly_config"

init_config
assert_failure $? "无读权限的配置文件应导致初始化失败"

# 恢复权限以便清理
chmod 644 "$readonly_config"

# 测试默认配置路径
echo "测试默认配置路径..."
unset PROTAB_CONFIG

# 创建默认配置文件
mkdir -p "$TEST_DATA_DIR/.protab"
cp "$TEST_DATA_DIR/test_config.json" "$TEST_DATA_DIR/.protab/config.json"

init_config
default_app_name=$(get_config "app.name")
assert_equals "ProTab Test" "$default_app_name" "默认配置路径应该工作"

teardown

test_suite_end