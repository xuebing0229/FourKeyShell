@echo off
cd /d "%~dp0"
set "GODOT=%~dp0tools\Godot_v4.7.2-stable_win64_console.exe"
"%GODOT%" --path . --verbose
echo.
echo 游戏已退出。上面的内容是启动日志。
pause
