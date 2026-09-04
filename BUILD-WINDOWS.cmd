@echo off
setlocal
cd /d "%~dp0"
title MCLauncher 1.0.0 Build

where makensis.exe >nul 2>nul
if errorlevel 1 (
  if exist "C:\Program Files (x86)\NSIS\makensis.exe" goto :nsis_ok
  if exist "C:\Program Files\NSIS\makensis.exe" goto :nsis_ok

  where winget.exe >nul 2>nul
  if not errorlevel 1 (
    echo [INFO] NSIS not found. Installing NSIS through Windows Package Manager...
    winget install --id NSIS.NSIS -e --source winget --accept-source-agreements --accept-package-agreements --silent --disable-interactivity
    if exist "C:\Program Files (x86)\NSIS\makensis.exe" goto :nsis_ok
    if exist "C:\Program Files\NSIS\makensis.exe" goto :nsis_ok
  )

  echo [ERROR] NSIS could not be installed automatically.
  echo Install it manually with:
  echo   winget install --id NSIS.NSIS -e --source winget
  echo Then run BUILD-WINDOWS.cmd again.
  pause
  exit /b 1
)

:nsis_ok
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-windows.ps1"
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" (
  echo [ERROR] Build failed with exit code %EXITCODE%.
) else (
  echo [OK] MCLauncher 1.0.0 build and installer are ready.
)
pause
exit /b %EXITCODE%
