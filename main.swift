// main.swift
// ProTab 主程序入口

import Foundation
import CoreFoundation

// 启动监听器
let monitor = TabKeyMonitor()
monitor.start()

// 保持程序运行
CFRunLoopRun()