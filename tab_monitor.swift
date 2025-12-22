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

        // 申请辅助功能权限
        if !AXIsProcessTrusted() {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(options)

            print("需要辅助功能权限")
            print("请在系统偏好设置 > 安全性与隐私 > 辅助功能中添加终端或此应用")
            return
        }

        setupEventTap()
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
            print("无法创建全局事件监听")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
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