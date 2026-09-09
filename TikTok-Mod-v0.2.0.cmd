@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title TikTok Mod v0.2.0 - TikTok 46.9.42

set "MOD_VERSION=0.2.0"
set "TARGET_VERSION=46.9.42"
set "OUTPUT=TikTok-Mod-v0.2.0.apk"
set "RUNTIME=%~dp0TikTok-Mod-Runtime"
set "MORPHE=%RUNTIME%\morphe-desktop-1.15.0-all.jar"
set "PATCHES=%RUNTIME%\patches-0.7.0.mpp"
set "MORPHE_SHA=727e3744aa5c0006474590de6f4041bd55edc59f3d6cb9b596e95f7116384506"
set "PATCHES_SHA=68f72ae49d99323beb33a11b1884e68b3bf73b6dc1f7f2b5bf082ad543bc4ccd"
set "MORPHE_URL=https://github.com/MorpheApp/morphe-desktop/releases/download/v1.15.0/morphe-desktop-1.15.0-all.jar"
set "PATCHES_URL=https://github.com/icysymmetra/tiktok-patches-for-morphe/releases/download/v0.7.0/patches-0.7.0.mpp"

cls
echo ================================================================
echo                  TikTok Mod v%MOD_VERSION%
echo                  Target: TikTok %TARGET_VERSION%
echo ================================================================
echo.

if not exist "%RUNTIME%" mkdir "%RUNTIME%" >nul 2>nul
if not exist "%RUNTIME%\morphe-data" mkdir "%RUNTIME%\morphe-data" >nul 2>nul
set "MORPHE_DATA_DIR=%RUNTIME%\morphe-data"

rem Find the source TikTok APK next to this script.
set "INPUT="
if exist "%~dp0tiktok-46-9-42.apk" set "INPUT=%~dp0tiktok-46-9-42.apk"
if not defined INPUT if exist "%~dp0tiktok-46-9-42-copy.apk" set "INPUT=%~dp0tiktok-46-9-42-copy.apk"
if not defined INPUT (
    for %%F in ("%~dp0*.apk") do (
        if /I not "%%~nxF"=="%OUTPUT%" if not defined INPUT set "INPUT=%%~fF"
    )
)

if not defined INPUT (
    echo [ERROR] TikTok APK was not found.
    echo Put your original TikTok %TARGET_VERSION% APK next to this file.
    echo Recommended filename: tiktok-46-9-42.apk
    echo.
    pause
    exit /b 2
)

echo [1/6] Input APK:
echo       %INPUT%
echo.

rem Prefer installed Java 21/17. If unavailable, download a private Temurin JRE 21.
set "JAVA_EXE="
where java >nul 2>nul
if not errorlevel 1 (
    for /f "tokens=3" %%V in ('java -version 2^>^&1 ^| findstr /i "version"') do if not defined JAVA_VER set "JAVA_VER=%%~V"
    set "JAVA_EXE=java"
)

if not defined JAVA_EXE (
    set "LOCAL_JRE=%RUNTIME%\jre21"
    if not exist "!LOCAL_JRE!\bin\java.exe" (
        echo [2/6] Java not found. Downloading Temurin JRE 21...
        powershell -NoProfile -ExecutionPolicy Bypass -Command ^
          "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue';" ^
          "$root=[IO.Path]::GetFullPath('%RUNTIME%'); $zip=Join-Path $root 'jre21.zip'; $unpack=Join-Path $root 'jre21-unpack';" ^
          "if(Test-Path $unpack){Remove-Item $unpack -Recurse -Force}; New-Item -ItemType Directory -Force -Path $unpack ^| Out-Null;" ^
          "Invoke-WebRequest -UseBasicParsing -Uri 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse' -OutFile $zip;" ^
          "Expand-Archive -Path $zip -DestinationPath $unpack -Force;" ^
          "$dir=Get-ChildItem $unpack -Directory ^| Select-Object -First 1; if(-not $dir){throw 'JRE archive layout is invalid'};" ^
          "$dst=Join-Path $root 'jre21'; if(Test-Path $dst){Remove-Item $dst -Recurse -Force}; Move-Item $dir.FullName $dst;" ^
          "Remove-Item $zip -Force; Remove-Item $unpack -Recurse -Force"
        if errorlevel 1 goto :download_error
    )
    set "JAVA_EXE=!LOCAL_JRE!\bin\java.exe"
) else (
    echo [2/6] Java found: !JAVA_VER!
)

if not exist "%MORPHE%" (
    echo [3/6] Downloading Morphe Desktop 1.15.0...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Invoke-WebRequest -UseBasicParsing -Uri '%MORPHE_URL%' -OutFile '%MORPHE%'"
    if errorlevel 1 goto :download_error
) else (
    echo [3/6] Morphe Desktop already cached.
)

if not exist "%PATCHES%" (
    echo [4/6] Downloading TikTok patch bundle 0.7.0...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Invoke-WebRequest -UseBasicParsing -Uri '%PATCHES_URL%' -OutFile '%PATCHES%'"
    if errorlevel 1 goto :download_error
) else (
    echo [4/6] Patch bundle already cached.
)

rem Verify exact upstream release hashes before executing downloaded files.
for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%MORPHE%').Hash.ToLowerInvariant()"') do set "MORPHE_ACTUAL=%%H"
if /I not "!MORPHE_ACTUAL!"=="%MORPHE_SHA%" (
    echo [ERROR] Morphe SHA-256 mismatch.
    echo Expected: %MORPHE_SHA%
    echo Actual:   !MORPHE_ACTUAL!
    del /q "%MORPHE%" >nul 2>nul
    pause
    exit /b 3
)

for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%PATCHES%').Hash.ToLowerInvariant()"') do set "PATCHES_ACTUAL=%%H"
if /I not "!PATCHES_ACTUAL!"=="%PATCHES_SHA%" (
    echo [ERROR] Patch bundle SHA-256 mismatch.
    echo Expected: %PATCHES_SHA%
    echo Actual:   !PATCHES_ACTUAL!
    del /q "%PATCHES%" >nul 2>nul
    pause
    exit /b 4
)

echo [5/6] Downloads verified.
echo.
echo Selected modifications:
echo   - Mod settings inside TikTok
echo   - Feed filter: ads / LIVE / Stories / Shop / photo posts
echo   - Watermark-free download patch where supported
echo   - Playback speed + remember speed
echo   - Seekbar + seek thumbnail
echo   - Always show publish date
echo   - Resume video after scrolling
echo   - Stop automatic looping
echo   - Sanitize shared links
echo   - Feed tab navigation controls
echo   - Hide floating promotions
echo   - Open external links directly
echo   - Google login fix after APK re-signing
echo   - SIM spoof hooks/presets ^(off until configured in settings^)
echo.
echo NOTE: %TARGET_VERSION% is newer than the patch bundle target.
echo Morphe will FORCE fingerprint matching and CONTINUE if an individual patch changed.
echo.

if exist "%OUTPUT%" del /q "%OUTPUT%" >nul 2>nul

set "PATCH_ARGS=--exclusive --continue-on-error --force"
set "PATCH_ARGS=!PATCH_ARGS! -e "Settings""
set "PATCH_ARGS=!PATCH_ARGS! -e "Feed filter""
set "PATCH_ARGS=!PATCH_ARGS! -e "Downloads""
set "PATCH_ARGS=!PATCH_ARGS! -e "Playback speed""
set "PATCH_ARGS=!PATCH_ARGS! -e "Show seekbar""
set "PATCH_ARGS=!PATCH_ARGS! -e "Show seekbar thumbnail""
set "PATCH_ARGS=!PATCH_ARGS! -e "Always show publish date""
set "PATCH_ARGS=!PATCH_ARGS! -e "Remember clear display""
set "PATCH_ARGS=!PATCH_ARGS! -e "Resume videos after scrolling""
set "PATCH_ARGS=!PATCH_ARGS! -e "Stop video looping""
set "PATCH_ARGS=!PATCH_ARGS! -e "Sanitize sharing links""
set "PATCH_ARGS=!PATCH_ARGS! -e "Feed tab navigation""
set "PATCH_ARGS=!PATCH_ARGS! -e "Hide floating promotions""
set "PATCH_ARGS=!PATCH_ARGS! -e "Open external links directly""
set "PATCH_ARGS=!PATCH_ARGS! -e "Fix Google login""
set "PATCH_ARGS=!PATCH_ARGS! -e "SIM spoof""

set "RESULT=%RUNTIME%\patch-result.json"
if exist "%RESULT%" del /q "%RESULT%" >nul 2>nul

echo [6/6] Patching TikTok. This can use several GB of RAM/disk space...
echo.
"!JAVA_EXE!" -Xms512m -Xmx6144m -jar "%MORPHE%" patch --patches "%PATCHES%" !PATCH_ARGS! --signer "TikTok Mod" --result-file "%RESULT%" -o "%OUTPUT%" "%INPUT%"
set "PATCH_EXIT=!ERRORLEVEL!"

echo.
if not exist "%OUTPUT%" (
    echo [ERROR] Patched APK was not produced. Exit code: !PATCH_EXIT!
    if exist "%RESULT%" (
        echo Result report: %RESULT%
    )
    echo Morphe logs: %RUNTIME%\morphe-data\logs
    echo.
    echo Because TikTok 46.9.42 changed too many bytecode fingerprints,
    echo the failed patch names in the report/log are the exact hooks that need porting next.
    pause
    exit /b !PATCH_EXIT!
)

for /f "delims=" %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%OUTPUT%').Hash.ToLowerInvariant()"') do set "OUTPUT_SHA=%%H"
for %%S in ("%OUTPUT%") do set "OUTPUT_SIZE=%%~zS"

echo ================================================================
echo SUCCESS
 echo Output: %~dp0%OUTPUT%
echo Size:   !OUTPUT_SIZE! bytes
echo SHA256: !OUTPUT_SHA!
echo ================================================================
echo.
echo Keep the folder "%RUNTIME%\morphe-data".
echo It contains the persistent signing keystore needed to update this mod later.
echo.
pause
exit /b 0

:download_error
echo.
echo [ERROR] Dependency download/setup failed.
echo Check Internet access and run this file again.
echo.
pause
exit /b 5
