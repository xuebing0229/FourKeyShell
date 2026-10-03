@echo off
setlocal
cd /d "%~dp0"
set "GODOT=%~dp0tools\Godot_v4.7.2-stable_win64_console.exe"
set "OUT=%~dp0dist\FourKeyShell"
set "EXE=%OUT%\FourKeyShell.exe"

if not exist "%GODOT%" (
  echo Godot executable not found: %GODOT%
  pause
  exit /b 1
)
if not exist "%~dp0tools\windows_release_x86_64.exe" (
  echo Windows export template not found: %~dp0tools\windows_release_x86_64.exe
  echo Prepare the Godot 4.7.2 Windows export template first.
  pause
  exit /b 1
)

if not exist "%OUT%" mkdir "%OUT%"
echo Building customer EXE...
"%GODOT%" --headless --path . --export-release "Windows Desktop" "%EXE%"
if errorlevel 1 (
  echo Build failed.
  pause
  exit /b 1
)
copy /Y "%~dp0CLIENT_README.txt" "%OUT%\CLIENT_README.txt" >nul
if not exist "%OUT%\Songs" mkdir "%OUT%\Songs"
echo.
echo Build complete: %EXE%
echo Customer package: %OUT%
pause
