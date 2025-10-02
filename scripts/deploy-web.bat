@echo off
setlocal

REM Single-click deploy wrapper for PowerShell script
REM Change renderer to canvaskit if you prefer
set "DIST_ID=EP13A2DVW6MQR"
set "RENDERER=html"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-web.ps1" -DistId "%DIST_ID%" -Renderer "%RENDERER%"

echo.
echo [Deploy finished] Press any key to close... (If it failed too fast, run the .ps1 from a terminal to see logs.)
pause >nul