#!/bin/bash
# ProTab - macOS Global Shortcut System

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    clear
    echo -e "\033[34m"
    echo "██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ "
    echo "██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗"
    echo "██████╔╝██████╔╝██║   ██║   ██║   ███████║██████╔╝"
    echo "██╔═══╝ ██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗"
    echo "██║     ██║  ██║╚██████╔╝   ██║   ██║  ██║██████╔╝"
    echo "╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═════╝ "
    echo -e "\033[0m"
    echo "Protab v2.0.1"
    echo ""
    
    pkill -f "tab_monitor" 2>/dev/null
    
    NEED_COMPILE=false
    if [ ! -f "$SCRIPT_DIR/tab_monitor" ]; then
        NEED_COMPILE=true
    elif [ "$SCRIPT_DIR/tab_monitor.swift" -nt "$SCRIPT_DIR/tab_monitor" ]; then
        NEED_COMPILE=true
    fi
    
    if [ "$NEED_COMPILE" = true ]; then
        echo "Compiling source code."
        if swiftc "$SCRIPT_DIR/tab_monitor.swift" -o "$SCRIPT_DIR/tab_monitor" 2>/dev/null; then
            echo "Compilation successful."
        else
            echo "Compilation failed."
            read -p "Press Enter to exit..."
            exit 1
        fi
    fi
    
    echo "Checking permissions."
    echo "Startup successful."
    echo ""
    echo "a - start Anti-API"
    echo "m - edit claude.md"
    echo "d - edit agents.md"
    echo "j - edit settings.json"
    echo "o - open Codex"
    echo "l - open Claude Code"
    echo "u - update Claude Code"
    echo "p - update Codex"
    echo "t - new terminal"
    echo "c - close terminal"
    echo "f - force quit"
    echo "r - freeup ram"
    echo "s - screenshot"
    echo "v - screenrecord"
    echo "x - toggle VPN"
    echo ""
    
    "$SCRIPT_DIR/tab_monitor" 2>/dev/null
}

main