$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $Root 'MCLauncher-source'

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw 'MCLauncher-source was not found. Run START.cmd first.'
}

function WriteUtf8([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function ReplaceLiteral([string]$Path, [string]$From, [string]$To) {
    $text = [System.IO.File]::ReadAllText($Path)
    if ($text.Contains($From)) {
        WriteUtf8 $Path ($text.Replace($From, $To))
        return $true
    }
    return $false
}

function ReplaceRegex([string]$Path, [string]$Pattern, [string]$Replacement) {
    $text = [System.IO.File]::ReadAllText($Path)
    $next = [System.Text.RegularExpressions.Regex]::Replace($text, $Pattern, $Replacement)
    if ($next -ne $text) {
        WriteUtf8 $Path $next
        return $true
    }
    return $false
}

$buildConfig = Join-Path $Source 'buildconfig\BuildConfig.cpp.in'
$application = Join-Path $Source 'launcher\Application.cpp'
$mainWindow = Join-Path $Source 'launcher\ui\MainWindow.cpp'
$dialog = Join-Path $Source 'launcher\ui\dialogs\TrioSoftIdDialog.cpp'
$themeSource = Join-Path $Root 'TrioSoftTheme.h'
$themeTarget = Join-Path $Source 'launcher\ui\themes\TrioSoftTheme.h'

foreach ($path in @($buildConfig, $application, $mainWindow, $dialog, $themeSource)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('Required file is missing: ' + $path)
    }
}

Write-Host '==> Applying TrioSoft App Hub design system to MCLauncher' -ForegroundColor Cyan

# Keep release version exactly 1.0.0.
ReplaceRegex $buildConfig '(?s)    if \(GIT_REFSPEC\.startsWith\("refs/heads/"\)\) \{.*?VERSION_CHANNEL = "unknown";\s*    \}' "`r`n    VERSION_CHANNEL = `"stable`";`r`n    GIT_TAG = versionString();" | Out-Null
ReplaceRegex $buildConfig '(?s)QString Config::printableVersionString\(\) const\s*\{.*?\r?\n\}' "QString Config::printableVersionString() const`r`n{`r`n    return versionString();`r`n}" | Out-Null
ReplaceLiteral $application 'BuildConfig.printableVersionString()' 'BuildConfig.versionString()' | Out-Null

# Install the site-derived global Qt theme and apply it at QApplication level.
Copy-Item -LiteralPath $themeSource -Destination $themeTarget -Force
$appText = [System.IO.File]::ReadAllText($application)
if (-not $appText.Contains('#include "ui/themes/TrioSoftTheme.h"')) {
    ReplaceLiteral $application '#include "ui/themes/ThemeManager.h"' "#include `"ui/themes/ThemeManager.h`"`r`n#include `"ui/themes/TrioSoftTheme.h`"" | Out-Null
}
$appText = [System.IO.File]::ReadAllText($application)
if (-not $appText.Contains('TrioSoftTheme::styleSheet()')) {
    ReplaceLiteral $application '    setDesktopFileName(BuildConfig.LAUNCHER_APPID);' "    setDesktopFileName(BuildConfig.LAUNCHER_APPID);`r`n`r`n    // TrioSoft App Hub visual system.`r`n    setStyle(QStyleFactory::create(QStringLiteral(`"Fusion`")));`r`n    setStyleSheet(TrioSoftTheme::styleSheet());" | Out-Null
}

# Remove the previous temporary green-only MainWindow skin. The global theme now owns all widgets/dialogs.
ReplaceRegex $mainWindow '(?s)\r?\n\s*// MCLauncher visual layer.*?ui->mainToolBar->setIconSize\(QSize\(20, 20\)\);\r?\n' "`r`n" | Out-Null
ReplaceLiteral $mainWindow 'MCLauncher by TrioSoft · triosoft.xyz' 'MCLauncher by TrioSoft | triosoft.xyz' | Out-Null

# TrioSoft ID: remove the old temporary dialog skin if it exists.
ReplaceRegex $dialog '(?s)\s*// MCLauncher TrioSoft dialog theme\s*setStyleSheet\(QStringLiteral\(".*?"\)\);\s*' "`r`n" | Out-Null

# Give the TrioSoft ID dialog the same card/surface hierarchy as /account on the site.
$dialogText = [System.IO.File]::ReadAllText($dialog)
if (-not $dialogText.Contains('TrioSoft App Hub dialog surface')) {
    $dialogCss = '    // TrioSoft App Hub dialog surface' + "`r`n" +
        '    setStyleSheet(QStringLiteral("QDialog{background:#000000;color:#f2f4f8;} QFrame{background:#16171b;border:1px solid rgba(255,255,255,28);border-radius:18px;} QLabel{background:transparent;color:#f2f4f8;} QPushButton{min-height:38px;padding:0 14px;border-radius:11px;background:#1c1d22;border:1px solid rgba(255,255,255,28);color:#f2f4f8;font-weight:600;} QPushButton:hover{background:#25262c;border-color:rgba(255,255,255,48);} QPushButton:pressed{background:#121318;} QPushButton:default{background:qlineargradient(x1:0,y1:0,x2:1,y2:1,stop:0 #0a78ee,stop:1 #6b68f5);border-color:rgba(124,166,255,120);color:#ffffff;font-weight:700;} QPushButton:default:hover{background:qlineargradient(x1:0,y1:0,x2:1,y2:1,stop:0 #2088f4,stop:1 #7976ff);}"));' + "`r`n"
    ReplaceRegex $dialog 'void TrioSoftIdDialog::buildUi\(\)\s*\{' ("void TrioSoftIdDialog::buildUi()`r`n{`r`n" + $dialogCss) | Out-Null
}

ReplaceLiteral $dialog '    setMinimumWidth(520);' "    setMinimumSize(600, 480);`r`n    resize(640, 520);" | Out-Null
ReplaceLiteral $dialog '    root->setContentsMargins(24, 24, 24, 24);' '    root->setContentsMargins(26, 26, 26, 26);' | Out-Null
ReplaceLiteral $dialog '    root->setSpacing(14);' '    root->setSpacing(16);' | Out-Null
ReplaceLiteral $dialog '    m_avatar->setFixedSize(72, 72);' '    m_avatar->setFixedSize(80, 80);' | Out-Null
ReplaceRegex $dialog 'm_avatar->setStyleSheet\(QStringLiteral\("[^"]*"\)\);' 'm_avatar->setStyleSheet(QStringLiteral("background:#0a0b0e;border:1px solid rgba(255,255,255,38);border-radius:40px;color:#dce7ff;font-size:23px;font-weight:700;"));' | Out-Null
ReplaceRegex $dialog 'description->setStyleSheet\(QStringLiteral\("[^"]*"\)\);' 'description->setStyleSheet(QStringLiteral("color:#a2a6b0;"));' | Out-Null
ReplaceRegex $dialog 'm_code->setStyleSheet\(QStringLiteral\("[^"]*"\)\);' 'm_code->setStyleSheet(QStringLiteral("padding:12px;background:rgba(10,120,238,28);border:1px solid rgba(77,164,255,90);border-radius:12px;color:#d9eaff;font-size:18px;font-weight:700;"));' | Out-Null
ReplaceRegex $dialog 'm_status->setStyleSheet\(QStringLiteral\("[^"]*"\)\);' 'm_status->setStyleSheet(QStringLiteral("color:#a2a6b0;padding:4px 2px;"));' | Out-Null
ReplaceLiteral $dialog '    m_site = new QPushButton(tr("Сайт TrioSoft"), this);' '    m_site = new QPushButton(tr("triosoft.xyz"), this);' | Out-Null

# Fallback initials are shown immediately while the avatar downloads.
$dialogText = [System.IO.File]::ReadAllText($dialog)
if (-not $dialogText.Contains('display.trimmed().left(2).toUpper()')) {
    ReplaceRegex $dialog '(    const QString display = !name\.isEmpty\(\) \? name : \(!username\.isEmpty\(\) \? username : tr\("[^\"]+"\)\);)' ('$1' + "`r`n    m_avatar->setPixmap(QPixmap());`r`n    m_avatar->setText(display.trimmed().left(2).toUpper());") | Out-Null
}

# Resolve /uploads/avatars/... against triosoft.xyz.
$dialogText = [System.IO.File]::ReadAllText($dialog)
if (-not $dialogText.Contains('kBaseUrl.resolved(avatarUrl)')) {
    ReplaceRegex $dialog '    const QString picture = profile\.value\(QStringLiteral\("picture"\)\)\.toString\(\);\s*    if \(!picture\.isEmpty\(\)\)\s*        loadAvatar\(picture\);' "    const QString picture = profile.value(QStringLiteral(`"picture`" )).toString();`r`n    if (!picture.isEmpty()) {`r`n        QUrl avatarUrl(picture);`r`n        if (avatarUrl.isRelative())`r`n            avatarUrl = kBaseUrl.resolved(avatarUrl);`r`n        loadAvatar(avatarUrl.toString());`r`n    }" | Out-Null
    ReplaceLiteral $dialog 'QStringLiteral("picture" )' 'QStringLiteral("picture")' | Out-Null
}

# Robust avatar download with redirects + cache for the toolbar icon.
$dialogText = [System.IO.File]::ReadAllText($dialog)
if (-not $dialogText.Contains('TrioSoftID/avatarBytes')) {
    $avatarFunction = @(
        'void TrioSoftIdDialog::loadAvatar(const QString &url)',
        '{',
        '    QNetworkRequest request{QUrl(url)};',
        '    request.setRawHeader("Accept", "image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8,*/*;q=0.5");',
        '    request.setRawHeader("Cache-Control", "no-cache");',
        '    request.setRawHeader("User-Agent", "MCLauncher/1.0.0 TrioSoftID");',
        '    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);',
        '    auto *reply = m_network->get(request);',
        '    connect(reply, &QNetworkReply::finished, this, [this, reply] {',
        '        const QByteArray bytes = reply->readAll();',
        '        const bool success = reply->error() == QNetworkReply::NoError;',
        '        reply->deleteLater();',
        '        QPixmap pixmap;',
        '        if (success && !bytes.isEmpty() && pixmap.loadFromData(bytes)) {',
        '            m_avatar->setText(QString());',
        '            m_avatar->setPixmap(pixmap.scaled(m_avatar->size(), Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));',
        '            QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));',
        '            settings.setValue(QStringLiteral("TrioSoftID/avatarBytes"), bytes);',
        '            settings.sync();',
        '        }',
        '    });',
        '}'
    ) -join "`r`n"
    ReplaceRegex $dialog '(?s)void TrioSoftIdDialog::loadAvatar\(const QString &url\)\s*\{.*?\r?\n\}' $avatarFunction | Out-Null
}

# Site-derived FREE/PREMIUM badge colors.
ReplaceRegex $dialog 'm_premium->setStyleSheet\(QStringLiteral\("background:#2b240d;[^"]*"\)\);' 'm_premium->setStyleSheet(QStringLiteral("background:rgba(224,180,95,32);border:1px solid rgba(224,180,95,90);border-radius:10px;color:#e0b45f;font-weight:800;padding:7px 10px;"));' | Out-Null
ReplaceRegex $dialog 'm_premium->setStyleSheet\(QStringLiteral\("background:#12211c;[^"]*"\)\);' 'm_premium->setStyleSheet(QStringLiteral("background:#1c1d22;border:1px solid rgba(255,255,255,24);border-radius:10px;color:#a2a6b0;font-weight:700;padding:7px 10px;"));' | Out-Null
ReplaceLiteral $dialog '        m_premium->setStyleSheet(QStringLiteral("font-weight:700; color:#d6a928;"));' '        m_premium->setStyleSheet(QStringLiteral("background:rgba(224,180,95,32);border:1px solid rgba(224,180,95,90);border-radius:10px;color:#e0b45f;font-weight:800;padding:7px 10px;"));' | Out-Null
ReplaceLiteral $dialog '        m_premium->setStyleSheet(QString());' '        m_premium->setStyleSheet(QStringLiteral("background:#1c1d22;border:1px solid rgba(255,255,255,24);border-radius:10px;color:#a2a6b0;font-weight:700;padding:7px 10px;"));' | Out-Null
ReplaceLiteral $dialog '    m_premium->setStyleSheet(QString());' '    m_premium->setStyleSheet(QStringLiteral("background:#1c1d22;border:1px solid rgba(255,255,255,24);border-radius:10px;color:#a2a6b0;font-weight:700;padding:7px 10px;"));' | Out-Null

# Make the TrioSoft ID toolbar action use the downloaded avatar after the dialog closes.
$mainText = [System.IO.File]::ReadAllText($mainWindow)
if (-not $mainText.Contains('#include <QSettings>')) {
    ReplaceLiteral $mainWindow '#include <QDir>' "#include <QDir>`r`n#include <QPixmap>`r`n#include <QSettings>" | Out-Null
}
$mainText = [System.IO.File]::ReadAllText($mainWindow)
if (-not $mainText.Contains('refreshTrioSoftIdIcon')) {
    $oldConnect = @(
        '    connect(trioSoftIdAction, &QAction::triggered, this, [this] {',
        '        TrioSoftIdDialog dialog(this);',
        '        dialog.exec();',
        '    });'
    ) -join "`r`n"
    $newConnect = @(
        '    auto refreshTrioSoftIdIcon = [trioSoftIdAction] {',
        '        QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));',
        '        const QByteArray bytes = settings.value(QStringLiteral("TrioSoftID/avatarBytes")).toByteArray();',
        '        QPixmap avatar;',
        '        if (!bytes.isEmpty() && avatar.loadFromData(bytes))',
        '            trioSoftIdAction->setIcon(QIcon(avatar.scaled(24, 24, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation)));',
        '        else',
        '            trioSoftIdAction->setIcon(QIcon(QStringLiteral(":/xyz.triosoft.mclauncher.svg")));',
        '    };',
        '    connect(trioSoftIdAction, &QAction::triggered, this, [this, refreshTrioSoftIdIcon] {',
        '        TrioSoftIdDialog dialog(this);',
        '        dialog.exec();',
        '        refreshTrioSoftIdIcon();',
        '    });',
        '    refreshTrioSoftIdIcon();'
    ) -join "`r`n"
    ReplaceLiteral $mainWindow $oldConnect $newConnect | Out-Null
}

$checks = @(
    @($buildConfig, 'VERSION_CHANNEL = "stable";'),
    @($application, '#include "ui/themes/TrioSoftTheme.h"'),
    @($application, 'TrioSoftTheme::styleSheet()'),
    @($dialog, 'TrioSoft App Hub dialog surface'),
    @($dialog, 'kBaseUrl.resolved(avatarUrl)'),
    @($dialog, 'TrioSoftID/avatarBytes'),
    @($themeTarget, '#0a78ee'),
    @($themeTarget, '#6b68f5')
)
foreach ($check in $checks) {
    $body = [System.IO.File]::ReadAllText([string]$check[0])
    if (-not $body.Contains([string]$check[1])) {
        throw ('TrioSoft UI validation failed: ' + [string]$check[1])
    }
}

Write-Host 'MCLauncher now uses the TrioSoft App Hub visual system.' -ForegroundColor Green
