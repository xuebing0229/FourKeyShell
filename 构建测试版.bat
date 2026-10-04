@echo off
setlocal
cd /d "%~dp0"
set "GODOT=%~dp0tools\Godot_v4.7.2-stable_win64_console.exe"
set "VERSION=0.2.0-beta.8"
set "OUT=%~dp0dist\FourKeyShell-test-v%VERSION%"
set "EXE=%OUT%\FourKeyShell.exe"
set "PACKAGE=%~dp0dist\FourKeyShell-test-v%VERSION%.zip"

if not exist "%GODOT%" (
  echo Godot executable not found: %GODOT%
  pause
  exit /b 1
)
if not exist "%~dp0tools\windows_release_x86_64.exe" (
  echo Windows export template not found.
  pause
  exit /b 1
)

if not exist "%OUT%" mkdir "%OUT%"
echo Building test EXE %VERSION%...
"%GODOT%" --headless --path . --export-release "Windows Desktop" "%EXE%"
if errorlevel 1 (
  echo Build failed.
  pause
  exit /b 1
)
copy /Y "%~dp0CLIENT_README.txt" "%OUT%\CLIENT_README.txt" >nul
copy /Y "%~dp0update_test_build.ps1" "%OUT%\update_test_build.ps1" >nul
if exist "%PACKAGE%" del /q "%PACKAGE%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%OUT%\*' -DestinationPath '%PACKAGE%' -Force"
if errorlevel 1 (
  echo Package failed.
  pause
  exit /b 1
)
echo.
echo Test build: %EXE%
echo Update package: %PACKAGE%
pause
