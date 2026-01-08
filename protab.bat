@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title ProTab for Windows

:main
cls
echo.
echo  [34m██████╗ ██████╗  ██████╗ ████████╗ █████╗ ██████╗ [0m
echo  [34m██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝██╔══██╗██╔══██╗[0m
echo  [34m██████╔╝██████╔╝██║   ██║   ██║   ███████║██████╔╝[0m
echo  [34m██╔═══╝ ██╔══██╗██║   ██║   ██║   ██╔══██║██╔══██╗[0m
echo  [34m██║     ██║  ██║╚██████╔╝   ██║   ██║  ██║██████╔╝[0m
echo  [34m╚═╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚═════╝ [0m
echo.
echo Protab v2.0.1
echo.
echo a - start Anti-API
echo m - edit claude.md
echo d - edit agents.md
echo j - edit settings.json
echo o - open Codex
echo l - open Claude Code
echo u - update Claude Code
echo p - update Codex
echo t - new terminal
echo c - close terminal
echo q - quit
echo.
choice /c amdjolopuctq /n /m ""

if errorlevel 12 goto quit
if errorlevel 11 goto new_terminal
if errorlevel 10 goto close_idle
if errorlevel 9 goto update_codex
if errorlevel 8 goto update_claude
if errorlevel 7 goto new_claude
if errorlevel 6 goto new_codex
if errorlevel 5 goto edit_settings
if errorlevel 4 goto edit_agents_md
if errorlevel 3 goto edit_claude_md
if errorlevel 2 goto start_anti_api
if errorlevel 1 goto start_anti_api

goto main

:start_anti_api
taskkill /f /im "anti-api.exe" >nul 2>&1
for %%p in (
    "%USERPROFILE%\Desktop\anti-api\anti-api-start.bat"
    "%USERPROFILE%\anti-api\anti-api-start.bat"
    "C:\anti-api\anti-api-start.bat"
) do if exist "%%~p" (start "" "%%~p" & goto main)
goto main

:edit_claude_md
set "f=%USERPROFILE%\.claude\CLAUDE.md"
if not exist "%f%" (mkdir "%USERPROFILE%\.claude" 2>nul & echo # CLAUDE.md > "%f%")
start "" notepad "%f%"
goto main

:edit_agents_md
set "f=%USERPROFILE%\.codex\AGENTS.md"
if not exist "%f%" (mkdir "%USERPROFILE%\.codex" 2>nul & echo # AGENTS.md > "%f%")
start "" notepad "%f%"
goto main

:edit_settings
set "f=%USERPROFILE%\.claude\settings.json"
if not exist "%f%" (mkdir "%USERPROFILE%\.claude" 2>nul & echo {} > "%f%")
start "" notepad "%f%"
goto main

:new_codex
start "" cmd /k "codex"
goto main

:new_claude
start "" cmd /k "claude"
goto main

:update_claude
start "" cmd /k "npm install -g @anthropic-ai/claude-code@latest"
goto main

:update_codex
start "" cmd /k "npm install -g @openai/codex@latest"
goto main

:close_idle
powershell -Command "Get-Process cmd -EA 0 | ? {$_.MainWindowTitle -eq ''} | Stop-Process -F -EA 0" >nul 2>&1
goto main

:new_terminal
start "" cmd
goto main

:quit
exit /b 0
