@echo off
setlocal

REM Single-click deploy wrapper for PowerShell script (root scripts)
REM Change renderer to canvaskit if you prefer
set "DIST_ID=EP13A2DVW6MQR"
set "RENDERER=html"

set "PS_SCRIPT=%~dp0deploy-web.ps1"

if not exist "%PS_SCRIPT%" (
  echo ERROR: PowerShell script not found: "%PS_SCRIPT%"
  echo Make sure scripts\deploy-web.ps1 exists.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -DistId "%DIST_ID%" -Renderer "%RENDERER%"

echo.
echo [Deploy finished] Press any key to close... (If it failed too fast, run the .ps1 from a terminal to see logs.)
pause >nul