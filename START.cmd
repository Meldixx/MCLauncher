@echo off
setlocal
cd /d "%~dp0"
title MCLauncher 1.0.0 - Source preparation
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare.ps1"
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" (
  echo [ERROR] Source preparation failed with exit code %EXITCODE%.
) else (
  echo [OK] MCLauncher 1.0.0 source is ready.
)
pause
exit /b %EXITCODE%
