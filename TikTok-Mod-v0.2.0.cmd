@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title TikTok Mod v0.2.0 - TikTok 46.9.42

set "MOD_VERSION=0.2.0"
set "TARGET_VERSION=46.9.42"
set "OUTPUT=TikTok-Mod-v0.2.0.apk"
set "RUNTIME=%~dp0TikTok-Mod-Runtime"
set "JRE=%RUNTIME%\jre21"
set "JAVA_EXE=%JRE%\bin\java.exe"
set "MORPHE=%RUNTIME%\morphe-desktop-1.15.0-all.jar"
set "PATCHES=%RUNTIME%\patches-0.7.0.mpp"
set "RESULT=%RUNTIME%\patch-result.json"
set "MORPHE_DATA_DIR=%RUNTIME%\morphe-data"

set "MORPHE_URL=https://github.com/MorpheApp/morphe-desktop/releases/download/v1.15.0/morphe-desktop-1.15.0-all.jar"
set "PATCHES_URL=https://github.com/icysymmetra/tiktok-patches-for-morphe/releases/download/v0.7.0/patches-0.7.0.mpp"
set "JRE_URL=https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse"
set "MORPHE_SHA=727e3744aa5c0006474590de6f4041bd55edc59f3d6cb9b596e95f7116384506"
set "PATCHES_SHA=68f72ae49d99323beb33a11b1884e68b3bf73b6dc1f7f2b5bf082ad543bc4ccd"

cls
echo ================================================================
echo                     TikTok Mod v%MOD_VERSION%
echo                     TikTok %TARGET_VERSION%
echo ================================================================
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Windows PowerShell was not found.
    pause
    exit /b 1
)

if not exist "%RUNTIME%" mkdir "%RUNTIME%" >nul 2>nul
if not exist "%MORPHE_DATA_DIR%" mkdir "%MORPHE_DATA_DIR%" >nul 2>nul

rem Locate the original APK beside this script.
set "INPUT="
if exist "%~dp0tiktok-46-9-42.apk" set "INPUT=%~dp0tiktok-46-9-42.apk"
if not defined INPUT if exist "%~dp0tiktok-46-9-42-copy.apk" set "INPUT=%~dp0tiktok-46-9-42-copy.apk"
if not defined INPUT (
    for %%F in ("%~dp0*.apk") do (
        if /I not "%%~nxF"=="%OUTPUT%" if not defined INPUT set "INPUT=%%~fF"
    )
)

if not defined INPUT (
    echo [ERROR] Original TikTok APK was not found.
    echo.
    echo Put TikTok %TARGET_VERSION% next to this CMD file and name it:
    echo     tiktok-46-9-42.apk
    echo.
    pause
    exit /b 2
)

echo [1/7] APK: %INPUT%
echo.

rem Always use an isolated Java 21 runtime so an old system Java cannot break Morphe.
if not exist "%JAVA_EXE%" (
    echo [2/7] Downloading private Temurin JRE 21...
    set "JRE_ZIP=%RUNTIME%\jre21.zip"
    set "JRE_UNPACK=%RUNTIME%\jre21-unpack"
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';" ^
      "$zip='%RUNTIME%\jre21.zip';$tmp='%RUNTIME%\jre21-unpack';$dst='%JRE%';" ^
      "if(Test-Path $tmp){Remove-Item -LiteralPath $tmp -Recurse -Force};" ^
      "New-Item -ItemType Directory -Path $tmp -Force ^| Out-Null;" ^
      "Invoke-WebRequest -UseBasicParsing -Uri '%JRE_URL%' -OutFile $zip;" ^
      "Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force;" ^
      "$src=Get-ChildItem -LiteralPath $tmp -Directory ^| Select-Object -First 1;" ^
      "if(-not $src){throw 'Invalid JRE archive'};" ^
      "if(Test-Path $dst){Remove-Item -LiteralPath $dst -Recurse -Force};" ^
      "Move-Item -LiteralPath $src.FullName -Destination $dst;" ^
      "Remove-Item -LiteralPath $zip -Force;Remove-Item -LiteralPath $tmp -Recurse -Force"
    if errorlevel 1 goto :download_error
) else (
    echo [2/7] Private Java 21 is ready.
)

"%JAVA_EXE%" -version >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Java runtime is damaged. Delete "%JRE%" and run again.
    pause
    exit /b 3
)

if not exist "%MORPHE%" (
    echo [3/7] Downloading Morphe Desktop 1.15.0...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Invoke-WebRequest -UseBasicParsing -Uri '%MORPHE_URL%' -OutFile '%MORPHE%'"
    if errorlevel 1 goto :download_error
) else (
    echo [3/7] Morphe Desktop is cached.
)

if not exist "%PATCHES%" (
    echo [4/7] Downloading TikTok patches 0.7.0...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Invoke-WebRequest -UseBasicParsing -Uri '%PATCHES_URL%' -OutFile '%PATCHES%'"
    if errorlevel 1 goto :download_error
) else (
    echo [4/7] TikTok patches are cached.
)

for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%MORPHE%').Hash.ToLowerInvariant()"') do set "MORPHE_ACTUAL=%%H"
if /I not "!MORPHE_ACTUAL!"=="%MORPHE_SHA%" (
    echo [ERROR] Morphe SHA-256 check failed.
    echo Expected: %MORPHE_SHA%
    echo Actual:   !MORPHE_ACTUAL!
    del /q "%MORPHE%" >nul 2>nul
    pause
    exit /b 4
)

for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%PATCHES%').Hash.ToLowerInvariant()"') do set "PATCHES_ACTUAL=%%H"
if /I not "!PATCHES_ACTUAL!"=="%PATCHES_SHA%" (
    echo [ERROR] Patch bundle SHA-256 check failed.
    echo Expected: %PATCHES_SHA%
    echo Actual:   !PATCHES_ACTUAL!
    del /q "%PATCHES%" >nul 2>nul
    pause
    exit /b 5
)

echo [5/7] Dependency hashes verified.

rem Validate exact patch names before spending time unpacking the APK.
set "PATCH_LIST=%RUNTIME%\patch-list.txt"
"%JAVA_EXE%" -jar "%MORPHE%" list-patches --patches "%PATCHES%" --out "%PATCH_LIST%" >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Morphe could not read the patch bundle.
    pause
    exit /b 6
)

echo [6/7] Patch bundle loaded.
echo.
echo Enabled TikTok Mod modules:
echo   * Settings
echo   * Feed filter ^(ads, LIVE, Stories, Shop, photo posts^)
echo   * Downloads
echo   * Playback speed + remembered speed
echo   * Seekbar + seek thumbnail
echo   * Always show publish date
echo   * Remember clear display
echo   * Resume videos after scrolling
echo   * Stop video looping
echo   * Sanitize sharing links
echo   * Feed tab navigation
echo   * Hide floating promotions
echo   * Open external links directly
echo   * Fix Google login after re-signing
echo   * SIM spoof controls
echo.
echo TikTok %TARGET_VERSION% is newer than the patch bundle target 46.2.3.
echo Morphe will use --force and will continue if one fingerprint no longer matches.
echo Failed patch details will be written to:
echo   %RESULT%
echo.

if exist "%OUTPUT%" del /q "%OUTPUT%" >nul 2>nul
if exist "%RESULT%" del /q "%RESULT%" >nul 2>nul

echo [7/7] Patching and signing TikTok...
echo.
"%JAVA_EXE%" -XX:MaxRAMPercentage=75 -jar "%MORPHE%" patch ^
  --patches "%PATCHES%" ^
  --exclusive ^
  --force ^
  --continue-on-error ^
  --bytecode-mode FULL ^
  -e "Settings" ^
  -e "Feed filter" ^
  -e "Downloads" ^
  -e "Playback speed" ^
  -e "Show seekbar" ^
  -e "Show seekbar thumbnail" ^
  -e "Always show publish date" ^
  -e "Remember clear display" ^
  -e "Resume videos after scrolling" ^
  -e "Stop video looping" ^
  -e "Sanitize sharing links" ^
  -e "Feed tab navigation" ^
  -e "Hide floating promotions" ^
  -e "Open external links directly" ^
  -e "Fix Google login" ^
  -e "SIM spoof" ^
  --signer "TikTok Mod" ^
  --result-file "%RESULT%" ^
  --out "%OUTPUT%" ^
  "%INPUT%"
set "PATCH_EXIT=!ERRORLEVEL!"

echo.
if not exist "%OUTPUT%" (
    echo ================================================================
    echo BUILD FAILED
    echo ================================================================
    echo Morphe exit code: !PATCH_EXIT!
    if exist "%RESULT%" echo Report: %RESULT%
    echo Logs:   %MORPHE_DATA_DIR%\logs
    echo.
    echo The report contains the exact 46.9.42 fingerprints that must be ported.
    pause
    exit /b !PATCH_EXIT!
)

for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%OUTPUT%').Hash.ToLowerInvariant()"') do set "OUTPUT_SHA=%%H"
for %%S in ("%OUTPUT%") do set "OUTPUT_SIZE=%%~zS"

echo ================================================================
echo BUILD FINISHED
echo ================================================================
echo APK:    %~dp0%OUTPUT%
echo Size:   !OUTPUT_SIZE! bytes
echo SHA256: !OUTPUT_SHA!
echo Report: %RESULT%
echo.
echo IMPORTANT: keep this folder for future updates:
echo   %MORPHE_DATA_DIR%
echo It contains the signing key. Losing it means a future build cannot update
 echo an already installed TikTok Mod signed with this key.
echo ================================================================
echo.
pause
exit /b 0

:download_error
echo.
echo [ERROR] Download failed.
echo Check your Internet connection and run TikTok-Mod-v0.2.0.cmd again.
echo.
pause
exit /b 7
