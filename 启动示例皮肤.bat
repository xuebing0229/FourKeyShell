@echo off
setlocal
cd /d "%~dp0"
set "GODOT=%~dp0tools\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo 找不到 Godot：%GODOT%
  pause
  exit /b 1
)
"%GODOT%" --path . -- --demo-chart
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
  echo.
  echo 游戏退出代码：%EXITCODE%
  pause
)
exit /b %EXITCODE%
