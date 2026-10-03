@echo off
cd /d "%~dp0"
set "GODOT=%~dp0tools\Godot_v4.7.2-stable_win64_console.exe"
"%GODOT%" --editor --path "%~dp0" --verbose
echo.
echo 编辑器已退出。上面的内容是启动日志。
pause
