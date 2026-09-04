$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $Root 'MCLauncher-source'

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw 'MCLauncher-source was not found. Run START.cmd first.'
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function Replace-Literal([string]$Path, [string]$From, [string]$To) {
    $text = [System.IO.File]::ReadAllText($Path)
    if ($text.Contains($From)) {
        Write-Utf8NoBom $Path ($text.Replace($From, $To))
        return $true
    }
    return $false
}

function Replace-Regex([string]$Path, [string]$Pattern, [string]$Replacement) {
    $text = [System.IO.File]::ReadAllText($Path)
    $next = [regex]::Replace($text, $Pattern, $Replacement)
    if ($next -ne $text) {
        Write-Utf8NoBom $Path $next
        return $true
    }
    return $false
}

$buildConfig = Join-Path $Source 'buildconfig\BuildConfig.cpp.in'
$application = Join-Path $Source 'launcher\Application.cpp'
$mainWindow = Join-Path $Source 'launcher\ui\MainWindow.cpp'
$dialog = Join-Path $Source 'launcher\ui\dialogs\TrioSoftIdDialog.cpp'

Write-Host '==> Polishing MCLauncher release UI' -ForegroundColor Cyan

# Never expose the Git branch/channel in a release build. The visible version is exactly 1.0.0.
Replace-Regex $buildConfig '(?s)    if \(GIT_REFSPEC\.startsWith\("refs/heads/"\)\) \{.*?    \} else \{\s*VERSION_CHANNEL = "unknown";\s*    \}' "    VERSION_CHANNEL = `"stable`";`r`n    GIT_TAG = versionString();" | Out-Null
Replace-Regex $buildConfig '(?s)QString Config::printableVersionString\(\) const\s*\{.*?\n\}' "QString Config::printableVersionString() const`r`n{`r`n    return versionString();`r`n}" | Out-Null
Replace-Literal $application 'BuildConfig.printableVersionString()' 'BuildConfig.versionString()' | Out-Null

# TrioSoft ID: fix relative /uploads/avatars/... URLs, cache the avatar for the toolbar,
# and replace the plain gray dialog with the MCLauncher green/black visual language.
Replace-Literal $dialog '    setWindowTitle(tr("TrioSoft ID — MCLauncher"));' '    setWindowTitle(tr("TrioSoft ID"));' | Out-Null
Replace-Literal $dialog '    setMinimumWidth(520);' "    setMinimumSize(590, 470);`r`n    resize(620, 500);" | Out-Null
Replace-Literal $dialog '    root->setContentsMargins(24, 24, 24, 24);' '    root->setContentsMargins(26, 24, 26, 24);' | Out-Null
Replace-Literal $dialog '    root->setSpacing(14);' '    root->setSpacing(16);' | Out-Null
Replace-Literal $dialog '    m_avatar->setFixedSize(72, 72);' '    m_avatar->setFixedSize(76, 76);' | Out-Null
Replace-Literal $dialog '    m_avatar->setStyleSheet(QStringLiteral("border:1px solid palette(mid); border-radius:18px; font-size:28px;"));' '    m_avatar->setStyleSheet(QStringLiteral("background:#11241d;border:2px solid #2ce6a0;border-radius:38px;color:#8fffd1;font-size:24px;font-weight:800;"));' | Out-Null
Replace-Literal $dialog '    description->setStyleSheet(QStringLiteral("color: palette(mid);"));' '    description->setStyleSheet(QStringLiteral("color:#8fa99f;"));' | Out-Null
Replace-Literal $dialog '    m_code->setStyleSheet(QStringLiteral("padding:12px; border:1px solid palette(mid); border-radius:12px; font-size:18px;"));' '    m_code->setStyleSheet(QStringLiteral("padding:12px;background:#0b2119;border:1px solid #2d6f57;border-radius:12px;color:#a6ffda;font-size:18px;font-weight:700;"));' | Out-Null
Replace-Literal $dialog '    m_status->setStyleSheet(QStringLiteral("color: palette(mid);"));' '    m_status->setStyleSheet(QStringLiteral("color:#8fa99f;padding:4px 2px;"));' | Out-Null
Replace-Literal $dialog '    m_site = new QPushButton(tr("Сайт TrioSoft"), this);' '    m_site = new QPushButton(tr("triosoft.xyz"), this);' | Out-Null

$dialogStyle = @'
void TrioSoftIdDialog::buildUi()
{
    setStyleSheet(QStringLiteral(R"TSQSS(
QDialog { background:#0a0f0e; color:#edf9f4; }
QLabel { color:#dcece5; }
QPushButton { min-height:34px; padding:0 14px; border-radius:9px; background:#151f1c; border:1px solid #29453b; color:#dcefe7; font-weight:700; }
QPushButton:hover { background:#1a3028; border-color:#35d89a; color:#ffffff; }
QPushButton:pressed { background:#133327; }
QPushButton:default { background:#22d990; border-color:#35eea5; color:#06110d; }
QPushButton:default:hover { background:#47efac; border-color:#71ffc0; }
QPushButton:disabled { background:#121816; border-color:#1f2a26; color:#627169; }
)TSQSS"));
'@
Replace-Regex $dialog 'void TrioSoftIdDialog::buildUi\(\)\s*\{' $dialogStyle | Out-Null

$profilePatch = @'
    const QString display = !name.isEmpty() ? name : (!username.isEmpty() ? username : tr("Пользователь TrioSoft"));
    {
        QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));
        settings.setValue(QStringLiteral("TrioSoftID/displayName"), display);
        settings.setValue(QStringLiteral("TrioSoftID/username"), username);
    }
    m_avatar->setPixmap(QPixmap());
    m_avatar->setText(display.trimmed().left(2).toUpper());
'@
Replace-Regex $dialog '    const QString display = !name\.isEmpty\(\) \? name : \(!username\.isEmpty\(\) \? username : tr\("Пользователь TrioSoft"\)\);' $profilePatch | Out-Null

$picturePatch = @'
    const QString picture = profile.value(QStringLiteral("picture")).toString();
    if (!picture.isEmpty()) {
        QUrl avatarUrl(picture);
        if (avatarUrl.isRelative())
            avatarUrl = kBaseUrl.resolved(avatarUrl);
        loadAvatar(avatarUrl.toString());
    }
'@
Replace-Regex $dialog '    const QString picture = profile\.value\(QStringLiteral\("picture"\)\)\.toString\(\);\s*    if \(!picture\.isEmpty\(\)\)\s*        loadAvatar\(picture\);' $picturePatch | Out-Null
Replace-Literal $dialog '        m_premium->setStyleSheet(QStringLiteral("font-weight:700; color:#d6a928;"));' '        m_premium->setStyleSheet(QStringLiteral("background:#2b240d;border:1px solid #80661c;border-radius:9px;color:#ffd868;font-weight:800;padding:7px 11px;"));' | Out-Null
Replace-Literal $dialog '        m_premium->setStyleSheet(QString());' '        m_premium->setStyleSheet(QStringLiteral("background:#12211c;border:1px solid #29483d;border-radius:9px;color:#9fbab0;font-weight:800;padding:7px 11px;"));' | Out-Null

$avatarPatch = @'
void TrioSoftIdDialog::loadAvatar(const QString &url)
{
    QNetworkRequest request{QUrl(url)};
    request.setRawHeader("Accept", "image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8,*/*;q=0.5");
    request.setRawHeader("Cache-Control", "no-cache");
    request.setRawHeader("User-Agent", "MCLauncher/1.0.0 TrioSoftID");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    auto *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const QByteArray bytes = reply->readAll();
        const bool success = reply->error() == QNetworkReply::NoError;
        reply->deleteLater();
        QPixmap pixmap;
        if (success && !bytes.isEmpty() && pixmap.loadFromData(bytes)) {
            m_avatar->setText(QString());
            m_avatar->setPixmap(pixmap.scaled(m_avatar->size(), Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation));
            QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));
            settings.setValue(QStringLiteral("TrioSoftID/avatarBytes"), bytes);
            settings.sync();
        }
    });
}
'@
Replace-Regex $dialog '(?s)void TrioSoftIdDialog::loadAvatar\(const QString &url\)\s*\{.*?\n\}' $avatarPatch | Out-Null

# Add a restrained green/black application skin. Keep all instance logic and layouts intact.
if (-not ([System.IO.File]::ReadAllText($mainWindow)).Contains('#include <QSettings>')) {
    Replace-Literal $mainWindow '#include <QDir>' "#include <QDir>`r`n#include <QPixmap>`r`n#include <QSettings>" | Out-Null
}

if (-not ([System.IO.File]::ReadAllText($mainWindow)).Contains('MCLauncher visual layer')) {
    $mainStyle = @'
    ui->setupUi(this);

    // MCLauncher visual layer — restrained dark surfaces with the green logo accent.
    setStyleSheet(styleSheet() + QStringLiteral(R"MCQSS(
QMainWindow { background:#0a0f0e; color:#eaf8f2; }
QToolBar { background:#0e1614; border:none; border-bottom:1px solid #20372f; spacing:5px; padding:5px 7px; }
QToolBar QToolButton { background:transparent; border:1px solid transparent; border-radius:8px; color:#dcefe7; margin:1px; padding:5px 8px; }
QToolBar QToolButton:hover { background:#153329; border-color:#2ac98e; color:#ffffff; }
QToolBar QToolButton:pressed, QToolBar QToolButton:checked { background:#194333; border-color:#35e8a4; }
QStatusBar { background:#090e0d; border-top:1px solid #1b3029; color:#8da99f; }
QMenu { background:#101816; border:1px solid #28443a; color:#e8f6f0; padding:6px; }
QMenu::item { border-radius:6px; padding:6px 24px 6px 10px; }
QMenu::item:selected { background:#194535; color:#ffffff; }
QPushButton { background:#151f1c; border:1px solid #29453b; border-radius:8px; color:#dcefe7; min-height:28px; padding:3px 10px; }
QPushButton:hover { background:#1a3028; border-color:#35d89a; color:#ffffff; }
QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox, QTextEdit, QPlainTextEdit { background:#0f1715; border:1px solid #29453b; border-radius:7px; color:#eaf8f2; selection-background-color:#21885f; padding:4px 7px; }
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus, QTextEdit:focus, QPlainTextEdit:focus { border-color:#35e8a4; }
QTreeView, QListView, QTableView { background:#0d1412; alternate-background-color:#101916; border:1px solid #1f352d; color:#dbece5; selection-background-color:#1b6047; selection-color:#ffffff; }
QHeaderView::section { background:#111b18; border:none; border-right:1px solid #20372f; border-bottom:1px solid #20372f; color:#a9c1b8; padding:5px; }
QScrollBar:vertical, QScrollBar:horizontal { background:#0b1110; border:none; margin:0; }
QScrollBar::handle:vertical, QScrollBar::handle:horizontal { background:#315347; border-radius:5px; min-height:22px; min-width:22px; }
QScrollBar::handle:vertical:hover, QScrollBar::handle:horizontal:hover { background:#3c8067; }
QScrollBar::add-line, QScrollBar::sub-line { width:0px; height:0px; }
)MCQSS"));
    ui->mainToolBar->setIconSize(QSize(20, 20));
'@
    Replace-Literal $mainWindow '    ui->setupUi(this);' $mainStyle | Out-Null
}

Replace-Literal $mainWindow 'MCLauncher by TrioSoft · triosoft.xyz' 'MCLauncher by TrioSoft | triosoft.xyz' | Out-Null

# Make the TrioSoft ID toolbar action show the cached account avatar after login.
$mainText = [System.IO.File]::ReadAllText($mainWindow)
if (-not $mainText.Contains('refreshTrioSoftIcon')) {
    $iconHelper = @'
    trioSoftIdAction->setToolTip(tr("Войти в TrioSoft ID"));
    auto refreshTrioSoftIcon = [trioSoftIdAction] {
        QSettings settings(QStringLiteral("TrioSoft"), QStringLiteral("MCLauncher"));
        const QByteArray bytes = settings.value(QStringLiteral("TrioSoftID/avatarBytes")).toByteArray();
        QPixmap avatar;
        if (!bytes.isEmpty() && avatar.loadFromData(bytes))
            trioSoftIdAction->setIcon(QIcon(avatar.scaled(24, 24, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation)));
        else
            trioSoftIdAction->setIcon(QIcon(QStringLiteral(":/xyz.triosoft.mclauncher.svg")));
    };
'@
    Replace-Literal $mainWindow '    trioSoftIdAction->setToolTip(tr("Войти в TrioSoft ID"));' $iconHelper | Out-Null

    $oldConnect = @'
    connect(trioSoftIdAction, &QAction::triggered, this, [this] {
        TrioSoftIdDialog dialog(this);
        dialog.exec();
    });
'@
    $newConnect = @'
    connect(trioSoftIdAction, &QAction::triggered, this, [this, refreshTrioSoftIcon] {
        TrioSoftIdDialog dialog(this);
        dialog.exec();
        refreshTrioSoftIcon();
    });
    refreshTrioSoftIcon();
'@
    Replace-Literal $mainWindow $oldConnect $newConnect | Out-Null
}

$checks = @(
    @{ Path=$buildConfig; Text='VERSION_CHANNEL = "stable";' },
    @{ Path=$application; Text='BuildConfig.versionString()' },
    @{ Path=$dialog; Text='kBaseUrl.resolved(avatarUrl)' },
    @{ Path=$dialog; Text='TrioSoftID/avatarBytes' },
    @{ Path=$mainWindow; Text='MCLauncher visual layer' },
    @{ Path=$mainWindow; Text='refreshTrioSoftIcon' }
)
foreach ($check in $checks) {
    if (-not ([System.IO.File]::ReadAllText($check.Path)).Contains($check.Text)) {
        throw "Polish validation failed: $($check.Text) was not found in $($check.Path)"
    }
}

Write-Host 'MCLauncher release polish applied.' -ForegroundColor Green
