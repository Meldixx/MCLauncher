$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $Root 'MCLauncher-source'
$Version = '1.0.0'
$DefaultMsaClientId = '2400e3a1-2671-4637-846c-3807cc6de2c5'
$DefaultElyClientId = 'mclauncher1'
$Dist = Join-Path $Root 'MCLauncher'
$Installer = Join-Path $Root "MCLauncher-v$Version.exe"

function Need([string]$Name, [string]$Help) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "$Name was not found. $Help" }
}

function Import-VsDevEnvironment {
    if (Get-Command 'cl.exe' -ErrorAction SilentlyContinue) { return }
    $pf86 = ${env:ProgramFiles(x86)}
    if (-not $pf86) { $pf86 = 'C:\Program Files (x86)' }
    $vswhere = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw 'MSVC compiler was not found. Install Visual Studio Build Tools 2022 with Desktop development with C++.'
    }
    $installPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
    if (-not $installPath) { throw 'Visual Studio Build Tools C++ workload was not found.' }
    $vsDevCmd = Join-Path $installPath 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path -LiteralPath $vsDevCmd -PathType Leaf)) { throw "VsDevCmd.bat was not found under $installPath" }

    Write-Host '==> Loading Visual Studio x64 build environment' -ForegroundColor Cyan
    $cmdLine = '"' + $vsDevCmd + '" -no_logo -arch=x64 && set'
    $envLines = & $env:ComSpec /d /s /c $cmdLine
    if ($LASTEXITCODE -ne 0) { throw 'Failed to initialize Visual Studio build environment.' }
    foreach ($line in $envLines) {
        $pos = $line.IndexOf('=')
        if ($pos -gt 0) {
            Set-Item -Path ('Env:' + $line.Substring(0, $pos)) -Value $line.Substring($pos + 1)
        }
    }
    if (-not (Get-Command 'cl.exe' -ErrorAction SilentlyContinue)) { throw 'cl.exe is still unavailable after Visual Studio initialization.' }
}

function Test-Java17Home([string]$Candidate) {
    if (-not $Candidate) { return $false }
    $javac = Join-Path $Candidate 'bin\javac.exe'
    if (-not (Test-Path -LiteralPath $javac -PathType Leaf)) { return $false }
    try {
        $versionText = ((& $javac -version 2>&1) | Out-String).Trim()
        return ($versionText -match '^javac\s+17(?:\.|\s|$)')
    } catch { return $false }
}

function Find-Java17Home {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:JAVA_HOME) { [void]$candidates.Add($env:JAVA_HOME) }
    foreach ($pattern in @(
        'C:\Java\jdk-17*',
        'C:\Program Files\Zulu\zulu-17*',
        'C:\Program Files\Eclipse Adoptium\jdk-17*',
        'C:\Program Files\Microsoft\jdk-17*',
        'C:\Program Files\Java\jdk-17*'
    )) {
        Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | ForEach-Object { [void]$candidates.Add($_.FullName) }
    }
    foreach ($candidate in $candidates) { if (Test-Java17Home $candidate) { return $candidate } }
    return $null
}

function Find-QtHome {
    if ($env:CMAKE_PREFIX_PATH) {
        foreach ($part in ($env:CMAKE_PREFIX_PATH -split ';')) {
            if ($part -and (Test-Path -LiteralPath (Join-Path $part 'lib\cmake\Qt6\Qt6Config.cmake') -PathType Leaf)) { return $part }
        }
    }
    $configs = Get-ChildItem -Path 'C:\Qt\*\msvc2022_64\lib\cmake\Qt6\Qt6Config.cmake' -File -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
    foreach ($cfg in $configs) {
        $qtHome = $cfg.Directory.Parent.Parent.Parent.FullName
        if ($qtHome) { return $qtHome }
    }
    return $null
}

function Find-MakeNSIS {
    $cmd = Get-Command 'makensis.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in @(
        (Join-Path $Root '.tools\nsis-3.12\makensis.exe'),
        'C:\Program Files (x86)\NSIS\makensis.exe',
        'C:\Program Files\NSIS\makensis.exe'
    )) { if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate } }
    return $null
}

function Test-PortableExecutable([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        $info = Get-Item -LiteralPath $Path
        if ($info.Length -lt 500000) { return $false }
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            return ($stream.ReadByte() -eq 0x4D -and $stream.ReadByte() -eq 0x5A)
        } finally { $stream.Dispose() }
    } catch { return $false }
}

function Ensure-MakeNSIS {
    $existing = Find-MakeNSIS
    if ($existing) { return $existing }

    $tools = Join-Path $Root '.tools'
    $setup = Join-Path $tools 'nsis-3.12-setup.exe'
    $extract = Join-Path $tools 'nsis-3.12'
    $oldArchive = Join-Path $tools 'nsis-3.12.zip'
    New-Item -ItemType Directory -Path $tools -Force | Out-Null

    # Older MCLauncher builds downloaded the SourceForge ZIP directly. Some mirrors
    # occasionally return a partial/HTML response, which makes Expand-Archive fail
    # with "End of Central Directory record could not be found". Remove that cache.
    if (Test-Path -LiteralPath $oldArchive -PathType Leaf) {
        Remove-Item -LiteralPath $oldArchive -Force -ErrorAction SilentlyContinue
    }

    $localMakensis = Join-Path $extract 'makensis.exe'
    if (Test-Path -LiteralPath $localMakensis -PathType Leaf) { return $localMakensis }

    if (-not (Test-PortableExecutable $setup)) {
        if (Test-Path -LiteralPath $setup) { Remove-Item -LiteralPath $setup -Force }
        Write-Host '==> Downloading official NSIS 3.12 installer' -ForegroundColor Cyan
        $downloadUrls = @(
            'https://sourceforge.net/projects/nsis/files/NSIS%203/3.12/nsis-3.12-setup.exe/download',
            'https://downloads.sourceforge.net/project/nsis/NSIS%203/3.12/nsis-3.12-setup.exe'
        )
        $downloaded = $false
        foreach ($url in $downloadUrls) {
            try {
                Invoke-WebRequest -UseBasicParsing -MaximumRedirection 10 -Uri $url -OutFile $setup
                if (Test-PortableExecutable $setup) {
                    $downloaded = $true
                    break
                }
            } catch {
                Write-Host "NSIS download attempt failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            if (Test-Path -LiteralPath $setup) { Remove-Item -LiteralPath $setup -Force -ErrorAction SilentlyContinue }
        }
        if (-not $downloaded) {
            throw 'Could not download a valid NSIS 3.12 installer. Install NSIS manually from https://nsis.sourceforge.io/Download and run BUILD-WINDOWS.cmd again.'
        }
    }

    Write-Host '==> Installing a local copy of NSIS 3.12 for this build' -ForegroundColor Cyan
    if (Test-Path -LiteralPath $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    $nsisArgs = @('/S', "/D=$extract")
    $process = Start-Process -FilePath $setup -ArgumentList $nsisArgs -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "NSIS setup failed with exit code $($process.ExitCode)" }

    $exe = Get-ChildItem -LiteralPath $extract -Filter makensis.exe -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        $systemNsis = Find-MakeNSIS
        if ($systemNsis) { return $systemNsis }
        throw 'NSIS setup finished, but makensis.exe was not found. Install NSIS manually from https://nsis.sourceforge.io/Download and run BUILD-WINDOWS.cmd again.'
    }
    return $exe.FullName
}

Need 'cmake.exe' 'Install CMake 3.28 or newer.'
Need 'ninja.exe' 'Install Ninja and make sure it is in PATH.'
Import-VsDevEnvironment

if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw 'MCLauncher-source was not found. Run START.cmd first.' }

if (-not $env:VCPKG_ROOT) {
    $defaultVcpkg = Join-Path $env:USERPROFILE 'vcpkg'
    if (Test-Path -LiteralPath (Join-Path $defaultVcpkg 'scripts\buildsystems\vcpkg.cmake') -PathType Leaf) { $env:VCPKG_ROOT = $defaultVcpkg }
}
if (-not $env:VCPKG_ROOT) { throw 'vcpkg was not found. Expected %USERPROFILE%\vcpkg or VCPKG_ROOT.' }
$vcpkgToolchain = Join-Path $env:VCPKG_ROOT 'scripts\buildsystems\vcpkg.cmake'
if (-not (Test-Path -LiteralPath $vcpkgToolchain -PathType Leaf)) { throw "VCPKG_ROOT is invalid: $env:VCPKG_ROOT" }

$javaHome = Find-Java17Home
if (-not $javaHome) { throw 'JDK 17 was not found. Install Microsoft OpenJDK 17, Zulu 17, Temurin 17, or another JDK 17.' }
$env:JAVA_HOME = $javaHome
$env:Path = (Join-Path $javaHome 'bin') + ';' + $env:Path
$javac = Join-Path $javaHome 'bin\javac.exe'
$java = Join-Path $javaHome 'bin\java.exe'
$jar = Join-Path $javaHome 'bin\jar.exe'
Write-Host "==> Java 17: $javaHome" -ForegroundColor Cyan

$qtHome = Find-QtHome
if (-not $qtHome) { throw 'Qt 6 MSVC 2022 x64 was not found under C:\Qt. Install Qt 6.10.x/6.11.x with Qt Network Authorization.' }
$env:CMAKE_PREFIX_PATH = $qtHome
Write-Host "==> Qt: $qtHome" -ForegroundColor Cyan

$env:BUILD_PLATFORM = 'triosoft'
$env:BUILD_TYPE = 'Release'
$env:ARTIFACT_NAME = ''
if ($env:CL) { if ($env:CL -notmatch '(^|\s)/EHsc(\s|$)') { $env:CL += ' /EHsc' } } else { $env:CL = '/EHsc' }

$configureArgs = @(
    '--fresh', '--preset', 'windows_msvc',
    '-DENABLE_LTO=OFF', '-DBUILD_TESTING=OFF',
    "-DJava_JAVAC_EXECUTABLE=$javac", "-DJava_JAVA_EXECUTABLE=$java", "-DJava_JAR_EXECUTABLE=$jar",
    "-DCMAKE_PREFIX_PATH=$qtHome",
    '-DLauncher_UPDATER_GITHUB_REPO=', '-DLauncher_BUILD_ARTIFACT='
)

# Public OAuth Client IDs may be embedded in a desktop application. Environment variables can override them for test builds.
$msaClientId = if ($env:MCLAUNCHER_MSA_CLIENT_ID) { $env:MCLAUNCHER_MSA_CLIENT_ID } else { $DefaultMsaClientId }
$elyClientId = if ($env:MCLAUNCHER_ELY_CLIENT_ID) { $env:MCLAUNCHER_ELY_CLIENT_ID } else { $DefaultElyClientId }
$configureArgs += "-DLauncher_MSA_CLIENT_ID=$msaClientId"
$configureArgs += "-DLauncher_ELY_CLIENT_ID=$elyClientId"

# CurseForge/Imgur remain optional. An empty CurseForge key disables CurseForge capability in the launcher.
if ($env:MCLAUNCHER_CURSEFORGE_API_KEY) { $configureArgs += "-DLauncher_CURSEFORGE_API_KEY=$($env:MCLAUNCHER_CURSEFORGE_API_KEY)" } else { $configureArgs += '-DLauncher_CURSEFORGE_API_KEY=' }
if ($env:MCLAUNCHER_IMGUR_CLIENT_ID) { $configureArgs += "-DLauncher_IMGUR_CLIENT_ID=$($env:MCLAUNCHER_IMGUR_CLIENT_ID)" } else { $configureArgs += '-DLauncher_IMGUR_CLIENT_ID=' }

Push-Location $Source
try {
    Write-Host '==> Configuring MCLauncher 1.0.0' -ForegroundColor Cyan
    & cmake.exe @configureArgs
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed with exit code $LASTEXITCODE" }

    Write-Host '==> Building Release (LTO disabled for reliable local linking)' -ForegroundColor Cyan
    & cmake.exe --build --preset windows_msvc --config Release --parallel 2
    if ($LASTEXITCODE -ne 0) { throw "CMake build failed with exit code $LASTEXITCODE" }

    Write-Host '==> Creating self-contained MCLauncher runtime' -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Dist) { Remove-Item -LiteralPath $Dist -Recurse -Force }
    New-Item -ItemType Directory -Path $Dist -Force | Out-Null
    & cmake.exe --install (Join-Path $Source 'build') --config Release --prefix $Dist
    if ($LASTEXITCODE -ne 0) { throw "CMake install failed with exit code $LASTEXITCODE" }

    $distExe = Join-Path $Dist 'mclauncher.exe'
    if (-not (Test-Path -LiteralPath $distExe -PathType Leaf)) { throw "Packaged executable was not found: $distExe" }

    $windeployqt = Join-Path $qtHome 'bin\windeployqt.exe'
    if (Test-Path -LiteralPath $windeployqt -PathType Leaf) {
        Write-Host '==> Deploying Qt runtime and MSVC runtime' -ForegroundColor Cyan
        & $windeployqt --release --compiler-runtime --no-translations $distExe
        if ($LASTEXITCODE -ne 0) { throw "windeployqt failed with exit code $LASTEXITCODE" }
    }

    foreach ($extra in @('LICENSE.txt','NOTICE.txt')) {
        $src = Join-Path $Root $extra
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $Dist $extra) -Force }
    }
    $sourceNotice = @"
MCLauncher v$Version — Corresponding Source

MCLauncher is GPL-3.0-only. Public binary releases must be accompanied by access to the corresponding source code.
Product website: https://triosoft.xyz
MCLauncher source: https://github.com/Meldixx/MCLauncher
Upstream source: https://github.com/ElyPrismLauncher/Launcher
Pinned upstream commit: 5ea65f7a8057f06382845b870a378e8b35e62559

Publish the exact MCLauncher v$Version source/patch set at https://github.com/Meldixx/MCLauncher alongside each public binary release.
"@
    [System.IO.File]::WriteAllText((Join-Path $Dist 'SOURCE-CODE.txt'), $sourceNotice, (New-Object System.Text.UTF8Encoding($false)))

    $required = @('Qt6Core.dll','Qt6Gui.dll','Qt6Widgets.dll','Qt6Network.dll','Qt6NetworkAuth.dll','Qt6Xml.dll','Qt6OpenGL.dll')
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Dist $_) -PathType Leaf) })
    if ($missing.Count -gt 0) { throw ('Runtime package is missing: ' + ($missing -join ', ')) }

    Write-Host '==> Building the public Windows installer' -ForegroundColor Cyan
    $makensis = Ensure-MakeNSIS
    if (Test-Path -LiteralPath $Installer) { Remove-Item -LiteralPath $Installer -Force }
    $nsi = Join-Path $Root 'MCLauncher-Installer.nsi'
    $icon = Join-Path $Root 'mclauncher.ico'
    & $makensis "/DAPP_VERSION=$Version" "/DSOURCE_DIR=$Dist" "/DOUT_FILE=$Installer" "/DAPP_ICON=$icon" $nsi
    if ($LASTEXITCODE -ne 0) { throw "NSIS installer build failed with exit code $LASTEXITCODE" }
    if (-not (Test-Path -LiteralPath $Installer -PathType Leaf)) { throw "Installer was not created: $Installer" }

    Write-Host ''
    Write-Host 'MCLauncher 1.0.0 is ready.' -ForegroundColor Green
    Write-Host "Installer: $Installer" -ForegroundColor Green
    Write-Host "Runnable folder: $Dist" -ForegroundColor Green
    Write-Host "Microsoft login Client ID: $msaClientId" -ForegroundColor Green
    Write-Host "Ely.by Client ID: $elyClientId" -ForegroundColor Green
    if (-not $env:MCLAUNCHER_CURSEFORGE_API_KEY) { Write-Host 'CurseForge integration: disabled (no first-party API key yet).' -ForegroundColor Yellow }
    Write-Host 'TrioSoft ID does not need a client secret. Its public Device Flow Client ID is obtained from triosoft.xyz.' -ForegroundColor Cyan

    try { Start-Process explorer.exe -ArgumentList ('/select,"' + $Installer + '"') } catch {}
} finally { Pop-Location }