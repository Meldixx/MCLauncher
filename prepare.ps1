$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Target = Join-Path $PackageRoot 'MCLauncher-source'
$Upstream = 'https://github.com/ElyPrismLauncher/Launcher.git'
$Branch = 'develop'
$UpstreamCommit = '5ea65f7a8057f06382845b870a378e8b35e62559'
$Version = '1.0.0'
$MicrosoftClientId = '2400e3a1-2671-4637-846c-3807cc6de2c5'
$ElyClientId = 'mclauncher1'

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Require-Command([string]$Name, [string]$Help) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "$Name was not found. $Help" }
}
function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}
function Replace-LiteralInFile([string]$Path, [System.Collections.IDictionary]$Map) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $text = [System.IO.File]::ReadAllText($Path)
    $original = $text
    foreach ($k in $Map.Keys) { $text = $text.Replace([string]$k, [string]$Map[$k]) }
    if ($text -ne $original) { Write-Utf8NoBom $Path $text }
}
function Replace-RegexInFile([string]$Path, [array]$Rules) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $text = [System.IO.File]::ReadAllText($Path)
    $original = $text
    foreach ($rule in $Rules) { $text = [regex]::Replace($text, $rule.Pattern, $rule.Replacement) }
    if ($text -ne $original) { Write-Utf8NoBom $Path $text }
}

function Restore-BrandingAssets {
    $pngPath = Join-Path $PackageRoot 'mclauncher-256.png'
    $icoPath = Join-Path $PackageRoot 'mclauncher.ico'
    $svgPath = Join-Path $PackageRoot 'mclauncher.svg'
    $compactSource = Join-Path $PackageRoot 'assets\mclauncher-logo.b64'
    if (-not (Test-Path -LiteralPath $compactSource -PathType Leaf)) {
        $parts = @(Get-ChildItem -Path (Join-Path $PackageRoot 'assets\mclauncher-logo.*.part') -File -ErrorAction SilentlyContinue | Sort-Object Name)
        if ($parts.Count -gt 0) {
            $joined = ($parts | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName).Trim() }) -join ''
            Write-Utf8NoBom $compactSource $joined
        }
    }

    # GitHub keeps a compact 128px PNG source. The downloadable build kit may
    # additionally contain the full-resolution user-supplied logo/ICO.
    if (-not (Test-Path -LiteralPath $pngPath -PathType Leaf)) {
        if (-not (Test-Path -LiteralPath $compactSource -PathType Leaf)) {
            throw 'Required MCLauncher branding source is missing: assets\mclauncher-logo.b64'
        }
        [System.IO.File]::WriteAllBytes($pngPath, [Convert]::FromBase64String([System.IO.File]::ReadAllText($compactSource).Trim()))
    }

    if (-not (Test-Path -LiteralPath $icoPath -PathType Leaf)) {
        # A modern ICO can contain a PNG payload. Build a one-image ICO around
        # the PNG so Windows resources and NSIS have a deterministic icon.
        $pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
        $stream = New-Object System.IO.MemoryStream
        $writer = New-Object System.IO.BinaryWriter($stream)
        try {
            $writer.Write([UInt16]0) # reserved
            $writer.Write([UInt16]1) # type = icon
            $writer.Write([UInt16]1) # image count
            $writer.Write([Byte]128) # width
            $writer.Write([Byte]128) # height
            $writer.Write([Byte]0)   # palette
            $writer.Write([Byte]0)   # reserved
            $writer.Write([UInt16]1) # planes
            $writer.Write([UInt16]32) # bpp
            $writer.Write([UInt32]$pngBytes.Length)
            $writer.Write([UInt32]22) # payload offset (6 + 16)
            $writer.Write($pngBytes)
            $writer.Flush()
            [System.IO.File]::WriteAllBytes($icoPath, $stream.ToArray())
        } finally {
            $writer.Dispose()
            $stream.Dispose()
        }
    }

    if (-not (Test-Path -LiteralPath $svgPath -PathType Leaf)) {
        $pngB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($pngPath))
        $svg = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256"><image width="256" height="256" href="data:image/png;base64,' + $pngB64 + '"/></svg>'
        Write-Utf8NoBom $svgPath $svg
    }
}

Restore-BrandingAssets

Write-Step 'Checking Git'
Require-Command 'git.exe' 'Install Git for Windows from https://git-scm.com/download/win'

if (Test-Path -LiteralPath $Target) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Target-backup-$stamp"
    Write-Step "Existing source found. Moving it to $(Split-Path -Leaf $backup)"
    Move-Item -LiteralPath $Target -Destination $backup
}

Write-Step 'Downloading the exact ElyPrismLauncher/PineconeMC source revision'
& git.exe clone --no-checkout $Upstream $Target
if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }

Write-Step "Checking out upstream commit $UpstreamCommit and submodules"
Push-Location $Target
try {
    & git.exe checkout --detach $UpstreamCommit
    if ($LASTEXITCODE -ne 0) { throw "Could not checkout upstream commit $UpstreamCommit" }
    & git.exe submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw "git submodule update failed with exit code $LASTEXITCODE" }

    & git.exe checkout -b "mclauncher-v$Version"
    if ($LASTEXITCODE -ne 0) { throw "Could not create branch mclauncher-v$Version" }
} finally { Pop-Location }

$rootCmake = Join-Path $Target 'CMakeLists.txt'
$brandCmake = Join-Path $Target 'program_info\CMakeLists.txt'
$buildConfigCpp = Join-Path $Target 'buildconfig\BuildConfig.cpp.in'
$launcherCmake = Join-Path $Target 'launcher\CMakeLists.txt'
$mainWindow = Join-Path $Target 'launcher\ui\MainWindow.cpp'

Write-Step 'Applying MCLauncher 1.0.0 identifiers, TrioSoft URLs and API-key cleanup'
Replace-RegexInFile $rootCmake @(
    @{ Pattern = 'set\(Launcher_APP_BINARY_NAME\s+"elyprismlauncher"'; Replacement = 'set(Launcher_APP_BINARY_NAME "mclauncher"' },
    @{ Pattern = 'set\(Launcher_VERSION_MAJOR\s+\d+\)'; Replacement = 'set(Launcher_VERSION_MAJOR 1)' },
    @{ Pattern = 'set\(Launcher_VERSION_MINOR\s+\d+\)'; Replacement = 'set(Launcher_VERSION_MINOR 0)' },
    @{ Pattern = 'set\(Launcher_VERSION_PATCH\s+\d+\)'; Replacement = 'set(Launcher_VERSION_PATCH 0)' },
    @{ Pattern = 'set\(Launcher_NEWS_RSS_URL\s+"[^"]*"'; Replacement = 'set(Launcher_NEWS_RSS_URL ""' },
    @{ Pattern = 'set\(Launcher_NEWS_OPEN_URL\s+"[^"]*"'; Replacement = 'set(Launcher_NEWS_OPEN_URL "https://triosoft.xyz"' },
    @{ Pattern = 'set\(Launcher_UPDATER_GITHUB_REPO\s+"[^"]*"'; Replacement = 'set(Launcher_UPDATER_GITHUB_REPO ""' },
    @{ Pattern = 'set\(Launcher_IMGUR_CLIENT_ID\s+"[^"]*"'; Replacement = 'set(Launcher_IMGUR_CLIENT_ID ""' },
    @{ Pattern = 'set\(Launcher_BUG_TRACKER_URL\s+"[^"]*"'; Replacement = 'set(Launcher_BUG_TRACKER_URL "https://triosoft.xyz/help"' },
    @{ Pattern = 'set\(Launcher_DISCORD_URL\s+"[^"]*"'; Replacement = 'set(Launcher_DISCORD_URL ""' },
    @{ Pattern = 'set\(Launcher_MSA_CLIENT_ID\s+"[^"]*"'; Replacement = ('set(Launcher_MSA_CLIENT_ID "' + $MicrosoftClientId + '"') },
    @{ Pattern = 'set\(Launcher_ELY_CLIENT_ID\s+"[^"]*"'; Replacement = ('set(Launcher_ELY_CLIENT_ID "' + $ElyClientId + '"') },
    @{ Pattern = 'set\(Launcher_CURSEFORGE_API_KEY\s+"[^"]*"'; Replacement = 'set(Launcher_CURSEFORGE_API_KEY ""' }
)

Replace-RegexInFile $brandCmake @(
    @{ Pattern = 'set\(Launcher_CommonName\s+"[^"]*"\)'; Replacement = 'set(Launcher_CommonName "MCLauncher")' },
    @{ Pattern = 'set\(Launcher_DisplayName\s+"[^"]*"\)'; Replacement = 'set(Launcher_DisplayName "MCLauncher")' },
    @{ Pattern = 'set\(Launcher_AppID\s+"[^"]*"\)'; Replacement = 'set(Launcher_AppID "xyz.triosoft.mclauncher")' },
    @{ Pattern = 'set\(Launcher_Domain\s+"[^"]*"\)'; Replacement = 'set(Launcher_Domain "triosoft.xyz")' },
    @{ Pattern = 'set\(Launcher_Git\s+"[^"]*"\)'; Replacement = 'set(Launcher_Git "https://triosoft.xyz")' },
    @{ Pattern = 'set\(Launcher_ENVName\s+"PINECONEMC"'; Replacement = 'set(Launcher_ENVName "MCLAUNCHER"' },
    @{ Pattern = 'set\(Launcher_UserAgent\s+"PrismLauncher/\$\{Launcher_VERSION_NAME\}"'; Replacement = 'set(Launcher_UserAgent "MCLauncher/${Launcher_VERSION_NAME}"' },
    @{ Pattern = 'set\(Launcher_Authors\s+"[^"]*"\)'; Replacement = 'set(Launcher_Authors "TrioSoft, PineconeMC, Prism Launcher & MultiMC Contributors")' },
    @{ Pattern = 'set\(Launcher_Copyright\s+"[^"]*"\)'; Replacement = 'set(Launcher_Copyright "© 2026 TrioSoft / MELDIX\\n© 2022-2026 PineconeMC Contributors\\n© 2022-2026 Prism Launcher Contributors\\n© 2021-2022 PolyMC Contributors\\n© 2012-2021 MultiMC Contributors")' },
    @{ Pattern = 'set\(Launcher_Copyright_Mac\s+"[^"]*"\s+PARENT_SCOPE\)'; Replacement = 'set(Launcher_Copyright_Mac "© 2026 TrioSoft / MELDIX, © 2022-2026 PineconeMC Contributors, © 2022-2026 Prism Launcher Contributors, © 2021-2022 PolyMC Contributors and © 2012-2021 MultiMC Contributors" PARENT_SCOPE)' }
)

Write-Step 'Making the visible version exactly 1.0.0'
Replace-RegexInFile $buildConfigCpp @(
    @{ Pattern = '(?s)    if \(GIT_REFSPEC\.startsWith\("refs/heads/"\)\) \{.*?    \}\n\n    NEWS_RSS_URL'; Replacement = "    VERSION_CHANNEL = `"`";`r`n`r`n    NEWS_RSS_URL" },
    @{ Pattern = '(?s)QString Config::printableVersionString\(\) const\n\{.*?\n\}'; Replacement = "QString Config::printableVersionString() const`r`n{`r`n    return versionString();`r`n}" }
)

Write-Step 'Renaming upstream application identifiers'
$textExtensions = @('.txt','.md','.cmake','.in','.cpp','.c','.cc','.h','.hpp','.ui','.qrc','.rc','.manifest','.desktop','.xml','.json','.yml','.yaml','.ps1','.cmd','.bat','.sh','.nsi','.scd','.java','.kt','.gradle','.properties','.toml','.conf','.cfg','.ini','.py','.js','.ts','.css','.html','.plist','.entitlements')
$literalMap = [ordered]@{
    'io.github.elyprismlauncher.ElyPrismLauncher' = 'xyz.triosoft.mclauncher'
    'elyprismlauncher' = 'mclauncher'
    'PINECONEMC_DISABLE_GLVULKAN' = 'MCLAUNCHER_DISABLE_GLVULKAN'
}
Get-ChildItem -LiteralPath $Target -Recurse -File -Force |
    Where-Object { $_.FullName -notmatch '\.git(\\|$)' -and $textExtensions -contains $_.Extension.ToLowerInvariant() } |
    ForEach-Object { Replace-LiteralInFile $_.FullName $literalMap }

Write-Step 'Renaming program_info branding files'
$programInfo = Join-Path $Target 'program_info'
Get-ChildItem -LiteralPath $programInfo -Recurse -Force |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        $newName = $_.Name.Replace('io.github.elyprismlauncher.ElyPrismLauncher', 'xyz.triosoft.mclauncher').Replace('elyprismlauncher', 'mclauncher')
        if ($newName -ne $_.Name) { Rename-Item -LiteralPath $_.FullName -NewName $newName }
    }
$oldMacIcon = Join-Path $programInfo 'ElyPrismLauncher.icon'
$newMacIcon = Join-Path $programInfo 'MCLauncher.icon'
if (Test-Path -LiteralPath $oldMacIcon) {
    if (Test-Path -LiteralPath $newMacIcon) { Remove-Item -LiteralPath $newMacIcon -Recurse -Force }
    Rename-Item -LiteralPath $oldMacIcon -NewName 'MCLauncher.icon'
}

Write-Step 'Installing the supplied MCLauncher logo'
Copy-Item -LiteralPath (Join-Path $PackageRoot 'mclauncher.ico') -Destination (Join-Path $programInfo 'mclauncher.ico') -Force
if (Test-Path -LiteralPath (Join-Path $PackageRoot 'mclauncher.icns')) { Copy-Item -LiteralPath (Join-Path $PackageRoot 'mclauncher.icns') -Destination (Join-Path $programInfo 'mclauncher.icns') -Force }
Copy-Item -LiteralPath (Join-Path $PackageRoot 'mclauncher.svg') -Destination (Join-Path $programInfo 'xyz.triosoft.mclauncher.svg') -Force
Copy-Item -LiteralPath (Join-Path $PackageRoot 'mclauncher-256.png') -Destination (Join-Path $programInfo 'xyz.triosoft.mclauncher_256.png') -Force

Write-Step 'Adding TrioSoft ID account integration'
$dialogDir = Join-Path $Target 'launcher\ui\dialogs'
Copy-Item -LiteralPath (Join-Path $PackageRoot 'TrioSoftIdDialog.h') -Destination (Join-Path $dialogDir 'TrioSoftIdDialog.h') -Force
Copy-Item -LiteralPath (Join-Path $PackageRoot 'TrioSoftIdDialog.cpp') -Destination (Join-Path $dialogDir 'TrioSoftIdDialog.cpp') -Force

Replace-RegexInFile $launcherCmake @(
    @{ Pattern = '(ui/dialogs/AboutDialog\.cpp\s*\n\s*ui/dialogs/AboutDialog\.h)'; Replacement = "`$1`r`n    ui/dialogs/TrioSoftIdDialog.cpp`r`n    ui/dialogs/TrioSoftIdDialog.h" }
)

Replace-RegexInFile $mainWindow @(
    @{ Pattern = '#include <QDir>'; Replacement = "#include <QDesktopServices>`r`n#include <QDir>" },
    @{ Pattern = '#include "ui/dialogs/AboutDialog\.h"'; Replacement = "#include `"ui/dialogs/AboutDialog.h`"`r`n#include `"ui/dialogs/TrioSoftIdDialog.h`"" },
    @{ Pattern = '    ui->setupUi\(this\);'; Replacement = @'
    ui->setupUi(this);

    // TrioSoft first-party integration: website + TrioSoft ID.
    auto* trioSoftIdAction = new QAction(QIcon(QStringLiteral(":/xyz.triosoft.mclauncher.svg")), tr("TrioSoft ID"), this);
    trioSoftIdAction->setToolTip(tr("Войти в TrioSoft ID"));
    connect(trioSoftIdAction, &QAction::triggered, this, [this] {
        TrioSoftIdDialog dialog(this);
        dialog.exec();
    });

    auto* trioSoftSiteAction = new QAction(QIcon::fromTheme("globe"), tr("TrioSoft"), this);
    trioSoftSiteAction->setToolTip(tr("Открыть triosoft.xyz"));
    connect(trioSoftSiteAction, &QAction::triggered, this, [] {
        QDesktopServices::openUrl(QUrl(QStringLiteral("https://triosoft.xyz")));
    });

    ui->mainToolBar->insertAction(ui->actionAccountsButton, trioSoftSiteAction);
    ui->mainToolBar->insertAction(ui->actionAccountsButton, trioSoftIdAction);

    auto* trioSoftBrandLabel = new QLabel(QStringLiteral("<a href=\"https://triosoft.xyz\" style=\"color:inherit;text-decoration:none;\">MCLauncher by TrioSoft · triosoft.xyz</a>"), this);
    trioSoftBrandLabel->setTextFormat(Qt::RichText);
    trioSoftBrandLabel->setOpenExternalLinks(true);
    ui->statusBar->addPermanentWidget(trioSoftBrandLabel);
'@ }
)

Write-Step 'Writing release/fork notice'
$notice = @"
# MCLauncher v$Version

MCLauncher is a modified derivative of PineconeMC / ElyPrismLauncher and Prism Launcher.

Modified and branded by TrioSoft on 2026-09-04.

- Product website: https://triosoft.xyz
- Upstream source: https://github.com/ElyPrismLauncher/Launcher
- Project lineage: PineconeMC / ElyPrismLauncher -> Prism Launcher -> PolyMC -> MultiMC
- Launcher code license: GNU GPL-3.0-only
- This fork is not endorsed by or affiliated with Prism Launcher, Ely.by, Mojang or Microsoft.
- Corresponding source must remain available under GPL-3.0 when binaries are distributed.

Upstream API credentials are intentionally removed. MCLauncher accepts first-party credentials at build time through environment variables.
"@
Write-Utf8NoBom (Join-Path $Target 'TRIOSOFT-NOTICE.md') $notice

$readme = Join-Path $Target 'README.md'
if (Test-Path -LiteralPath $readme) {
    $old = [System.IO.File]::ReadAllText($readme)
    $header = @"
# MCLauncher

> MCLauncher 1.0.0 by TrioSoft — https://triosoft.xyz
> Custom GPL-3.0 fork prepared from ElyPrismLauncher/PineconeMC.
> Includes TrioSoft ID Device Flow integration. Not affiliated with Prism Launcher, Ely.by, Mojang or Microsoft.

---

"@
    Write-Utf8NoBom $readme ($header + $old)
}

Write-Step 'Validating critical release changes'
$checks = @(
    @{ Path = $rootCmake; Text = 'set(Launcher_APP_BINARY_NAME "mclauncher"' },
    @{ Path = $rootCmake; Text = 'set(Launcher_VERSION_MAJOR 1)' },
    @{ Path = $rootCmake; Text = 'set(Launcher_VERSION_MINOR 0)' },
    @{ Path = $rootCmake; Text = 'set(Launcher_VERSION_PATCH 0)' },
    @{ Path = $brandCmake; Text = 'set(Launcher_DisplayName "MCLauncher")' },
    @{ Path = $brandCmake; Text = 'set(Launcher_AppID "xyz.triosoft.mclauncher")' },
    @{ Path = $mainWindow; Text = 'TrioSoftIdDialog dialog(this);' },
    @{ Path = $mainWindow; Text = 'MCLauncher by TrioSoft' },
    @{ Path = $launcherCmake; Text = 'ui/dialogs/TrioSoftIdDialog.cpp' }
)
foreach ($check in $checks) {
    $body = [System.IO.File]::ReadAllText($check.Path)
    if (-not $body.Contains($check.Text)) { throw "Validation failed: '$($check.Text)' was not found in $($check.Path)" }
}

Write-Step 'Done'
Write-Host "Source: $Target" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Green
Write-Host 'TrioSoft ID client: tsc_mclauncher_windows_v100 (public Device Flow client).' -ForegroundColor Green
Write-Host "Microsoft account Client ID: $MicrosoftClientId" -ForegroundColor Green
Write-Host "Ely.by Client ID: $ElyClientId" -ForegroundColor Green
Write-Host 'CurseForge support is disabled until a first-party API key is supplied.' -ForegroundColor Yellow
Write-Host "Pinned upstream commit: $UpstreamCommit" -ForegroundColor Cyan
