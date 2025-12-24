import Cocoa
import Carbon

class TabKeyMonitor {
    private var eventTap: CFMachPort?
    private let config = ProTabConfig.shared
    private var isWaitingForLetter = false
    private var tabPressTime: DispatchTime?

    func start() {
        // 打印配置信息（仅在调试模式下）
        config.printConfiguration()

        // 检查并申请辅助功能权限
        if !AXIsProcessTrusted() {
            // 显示系统权限弹窗
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(options)
            
            // 显示用户友好的通知
            showNotification(title: "ProTab 需要权限", message: "请在系统设置中授予辅助功能权限，然后重新启动 ProTab")
            
            // 打开系统设置的辅助功能页面
            openAccessibilitySettings()
            
            print("⚠️ 需要辅助功能权限")
            print("请在系统设置 > 隐私与安全性 > 辅助功能中添加此应用")
            print("授权后请重新启动 ProTab")
            
            // 等待几秒让用户看到提示
            Thread.sleep(forTimeInterval: 3)
            return
        }
        
        // 权限已获得，显示成功通知
        showNotification(title: "ProTab 已启动", message: "全局快捷键已激活 ✓")
        print("✅ ProTab 全局快捷键监听器已启动")

        setupEventTap()
    }
    
    private func showNotification(title: String, message: String) {
        let script = "display notification \"\(message)\" with title \"\(title)\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    private func openAccessibilitySettings() {
        // 打开系统设置的辅助功能页面
        let script = """
        tell application "System Settings"
            activate
            delay 0.5
        end tell
        do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'"
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<TabKeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        guard let eventTap = eventTap else {
            print("❌ 无法创建全局事件监听")
            print("   请确保在系统设置 > 隐私与安全性 > 辅助功能 中已授权")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("✅ 全局事件监听已启动")
        
        // 添加事件tap失效检测和自动重启
        // macOS会在eventTap响应太慢时禁用它，我们需要监控并重启
        DispatchQueue.global().async { [weak self] in
            while true {
                Thread.sleep(forTimeInterval: 5.0)
                
                guard let self = self, let tap = self.eventTap else {
                    break
                }
                
                // 检查事件tap是否仍然启用
                if !CGEvent.tapIsEnabled(tap: tap) {
                    print("⚠️ 事件监听被禁用，正在重新启用...")
                    CGEvent.tapEnable(tap: tap, enable: true)
                    print("✅ 事件监听已重新启用")
                }
            }
        }
    }

    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // 忽略修饰键组合
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) || flags.contains(.maskShift) {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            // Tab键按下 (keyCode 48)
            if keyCode == 48 {
                isWaitingForLetter = true
                tabPressTime = DispatchTime.now()

                // 设置超时，从配置读取
                let timeoutMs = config.waitTimeoutMs
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) { [weak self] in
                    self?.isWaitingForLetter = false
                }

                // 阻止Tab的默认行为
                return nil
            }

            // 如果正在等待字母键
            if isWaitingForLetter {
                let timeoutMs = config.waitTimeoutMs
                if let tabTime = tabPressTime, DispatchTime.now() < tabTime + .milliseconds(timeoutMs) {
                    let letter = keyCodeToLetter(keyCode)
                    if !letter.isEmpty {
                        executeCommand(for: letter)
                        isWaitingForLetter = false
                        return nil // 阻止字母键的默认行为
                    }
                }
                isWaitingForLetter = false
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func executeCommand(for key: String) {
        // 从配置获取脚本路径
        guard let scriptPath = config.getShortcutPath(for: key.lowercased()) else {
            if config.debugMode {
                print("No shortcut configured for key: \(key)")
            }
            return
        }

        // 检查脚本文件是否存在
        if !FileManager.default.fileExists(atPath: scriptPath) {
            if config.debugMode {
                print("Script not found: \(scriptPath)")
            }
            return
        }

        if config.debugMode {
            print("Executing: \(scriptPath)")
        }

        DispatchQueue.global().async {
            let process = Process()
            process.launchPath = "/bin/bash"
            process.arguments = [scriptPath]
            try? process.run()
        }
    }

    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
    }
}

// 键码到字母的映射
func keyCodeToLetter(_ keyCode: Int64) -> String {
    switch keyCode {
    case 0: return "a"
    case 11: return "b"
    case 8: return "c"
    case 2: return "d"
    case 14: return "e"
    case 3: return "f"
    case 5: return "g"
    case 4: return "h"
    case 34: return "i"
    case 38: return "j"
    case 40: return "k"
    case 37: return "l"
    case 46: return "m"
    case 45: return "n"
    case 31: return "o"
    case 35: return "p"
    case 12: return "q"
    case 15: return "r"
    case 1: return "s"
    case 17: return "t"
    case 32: return "u"
    case 9: return "v"
    case 13: return "w"
    case 7: return "x"
    case 16: return "y"
    case 6: return "z"
    default: return ""
    }
}