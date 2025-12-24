import Foundation

// ProTab Configuration Manager for Swift
class ProTabConfig {
    static let shared = ProTabConfig()

    private var config: [String: Any] = [:]
    private var configPath: String = ""

    init() {
        loadConfiguration()
    }

    private func loadConfiguration() {
        // 配置文件查找优先级
        var possiblePaths: [String] = []

        // 1. 环境变量指定的路径
        if let envPath = ProcessInfo.processInfo.environment["PROTAB_CONFIG"] {
            possiblePaths.append(envPath)
        }

        // 2. 用户配置目录
        if let homeDir = ProcessInfo.processInfo.environment["HOME"] {
            possiblePaths.append("\(homeDir)/.protab/config.json")
        }

        // 3. 当前目录
        let currentDir = FileManager.default.currentDirectoryPath
        possiblePaths.append("\(currentDir)/config.json")

        // 4. 可执行文件同目录
        if let executablePath = Bundle.main.executablePath {
            let executableDir = (executablePath as NSString).deletingLastPathComponent
            possiblePaths.append("\(executableDir)/config.json")
        }

        // 5. 默认备选路径
        possiblePaths.append("/usr/local/etc/protab/config.json")

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                configPath = path
                break
            }
        }

        guard !configPath.isEmpty else {
            print("Warning: No configuration file found")
            loadDefaultConfig()
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                config = jsonObject
                print("Configuration loaded from: \(configPath)")
            } else {
                print("Error: Invalid JSON format in configuration file")
                loadDefaultConfig()
            }
        } catch {
            print("Error reading configuration file: \(error)")
            loadDefaultConfig()
        }
    }

    private func loadDefaultConfig() {
        // 如果无法读取配置文件，使用默认配置
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? "/Users/\(NSUserName())"
        let currentDir = FileManager.default.currentDirectoryPath

        config = [
            "paths": [
                "work_directory": currentDir,
                "claude_config_dir": "\(homeDir)/.claude",
                "shortcuts_dir": "\(currentDir)/shortcuts"
            ],
            "keyboard": [
                "wait_timeout_ms": 500,
                "shortcuts": [
                    "c": "start_api.sh",
                    "a": "auth_api.sh",
                    "m": "edit_claude_md.sh",
                    "j": "edit_settings_json.sh",
                    "l": "new_claude_code.sh",
                    "u": "update_claude_code.sh",
                    "i": "start_core_inject.sh",
                    "f": "open_force_quit.sh",
                    "t": "new_terminal.sh",
                    "p": "new_private_tab.sh",
                    "b": "upload_to_r2.sh",
                    "r": "clean_ram.sh",
                    "q": "network_test.sh",
                    "s": "screenshot.sh",
                    "v": "record.sh"
                ]
            ],
            "ui": [
                "notification_title": "ProTab",
                "app_name": "ProTab"
            ],
            "system": [
                "require_accessibility_permission": true,
                "debug_mode": false
            ]
        ]

        print("Using default configuration")
    }

    // 获取配置值的通用方法
    func getValue<T>(_ keyPath: String, defaultValue: T) -> T {
        let keys = keyPath.split(separator: ".").map(String.init)
        var current: Any = config

        for key in keys {
            if let dict = current as? [String: Any],
               let value = dict[key] {
                current = value
            } else {
                return defaultValue
            }
        }

        // 处理环境变量替换
        if let stringValue = current as? String {
            let expandedValue = expandEnvironmentVariables(stringValue)
            return (expandedValue as? T) ?? defaultValue
        }

        return (current as? T) ?? defaultValue
    }

    // 环境变量替换
    private func expandEnvironmentVariables(_ input: String) -> String {
        var result = input
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let workDir = getValue("paths.work_directory", defaultValue: FileManager.default.currentDirectoryPath)

        result = result.replacingOccurrences(of: "${HOME}", with: homeDir)
        result = result.replacingOccurrences(of: "${WORK_DIR}", with: workDir)

        return result
    }

    // 便捷方法
    var workDirectory: String {
        return getValue("paths.work_directory", defaultValue: FileManager.default.currentDirectoryPath)
    }

    var shortcutsDirectory: String {
        // 支持两种配置键名
        let dir1 = getValue("paths.scripts_directory", defaultValue: "")
        if !dir1.isEmpty {
            return dir1
        }
        return getValue("paths.shortcuts_dir", defaultValue: "\(workDirectory)/shortcuts")
    }

    var claudeConfigDirectory: String {
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
        return getValue("paths.claude_config_dir", defaultValue: "\(homeDir)/.claude")
    }

    var waitTimeoutMs: Int {
        return getValue("keyboard.wait_timeout_ms", defaultValue: 500)
    }

    var notificationTitle: String {
        return getValue("ui.notification_title", defaultValue: "ProTab")
    }

    var appName: String {
        return getValue("ui.app_name", defaultValue: "ProTab")
    }

    var debugMode: Bool {
        return getValue("system.debug_mode", defaultValue: false)
    }

    func getShortcut(for key: String) -> String? {
        return getValue("keyboard.shortcuts.\(key)", defaultValue: nil as String?)
    }

    func getShortcutPath(for key: String) -> String? {
        if let scriptName = getShortcut(for: key) {
            return "\(shortcutsDirectory)/\(scriptName)"
        }
        return nil
    }

    // 获取所有快捷键
    var allShortcuts: [String: String] {
        return getValue("keyboard.shortcuts", defaultValue: [:])
    }

    // 调试信息
    func printConfiguration() {
        if debugMode {
            print("ProTab Configuration Debug:")
            print("Config file: \(configPath)")
            print("Work directory: \(workDirectory)")
            print("Shortcuts directory: \(shortcutsDirectory)")
            print("Claude config: \(claudeConfigDirectory)")
            print("Wait timeout: \(waitTimeoutMs)ms")
            print("Notification title: \(notificationTitle)")
            print("Shortcuts: \(allShortcuts)")
        }
    }
}