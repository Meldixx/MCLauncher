@echo off
setlocal
cd /d "%~dp0"
title MCLauncher 1.0.0 - Source preparation
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare.ps1"
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" goto :failed

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0polish-release.ps1"
set EXITCODE=%ERRORLEVEL%
if not "%EXITCODE%"=="0" goto :failed

echo.
echo [OK] MCLauncher 1.0.0 source is ready and polished.
pause
exit /b 0

:failed
echo.
echo [ERROR] Source preparation failed with exit code %EXITCODE%.
pause
exit /b %EXITCODE%
