#!/bin/bash
# Tab+C - 关闭所有空闲的终端窗口

# 使用AppleScript检测并关闭空闲终端
closed_count=$(osascript << 'EOF'
set closedCount to 0

tell application "Terminal"
    set windowList to every window
    
    repeat with theWindow in windowList
        set tabList to every tab of theWindow
        set allTabsIdle to true
        
        repeat with theTab in tabList
            -- 检查标签页是否繁忙（有进程运行）
            if busy of theTab then
                set allTabsIdle to false
                exit repeat
            end if
        end repeat
        
        -- 如果所有标签页都空闲，关闭窗口
        if allTabsIdle then
            close theWindow
            set closedCount to closedCount + 1
        end if
    end repeat
end tell

return closedCount
EOF
)

if [ "$closed_count" -gt 0 ]; then
    osascript -e "display notification \"Closed $closed_count idle window(s)\" with title \"ProTab\""
else
    osascript -e 'display notification "No idle windows" with title "ProTab"'
fi
