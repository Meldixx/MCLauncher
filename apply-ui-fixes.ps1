$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source = Join-Path $Root 'MCLauncher-source'

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw 'MCLauncher-source was not found. Run START.cmd first.'
}

function D([string]$Value) {
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
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

foreach ($path in @($buildConfig, $application, $mainWindow, $dialog)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('Required source file is missing: ' + $path)
    }
}

Write-Host '==> Applying MCLauncher UI fixes' -ForegroundColor Cyan

ReplaceRegex $buildConfig (D 'KD9zKVxzKmlmIFwoR0lUX1JFRlNQRUNcLnN0YXJ0c1dpdGhcKCJyZWZzL2hlYWRzLyJcKVwpIFx7Lio/VkVSU0lPTl9DSEFOTkVMID0gInVua25vd24iO1xzKlx9') (D 'DQogICAgVkVSU0lPTl9DSEFOTkVMID0gInN0YWJsZSI7DQogICAgR0lUX1RBRyA9IHZlcnNpb25TdHJpbmcoKTs=') | Out-Null
ReplaceRegex $buildConfig (D 'KD9zKVFTdHJpbmcgQ29uZmlnOjpwcmludGFibGVWZXJzaW9uU3RyaW5nXChcKSBjb25zdFxzKlx7Lio/XHI/XG5cfQ==') (D 'UVN0cmluZyBDb25maWc6OnByaW50YWJsZVZlcnNpb25TdHJpbmcoKSBjb25zdA0Kew0KICAgIHJldHVybiB2ZXJzaW9uU3RyaW5nKCk7DQp9') | Out-Null
ReplaceLiteral $application 'BuildConfig.printableVersionString()' 'BuildConfig.versionString()' | Out-Null

ReplaceLiteral $dialog '    setMinimumWidth(520);' ("    setMinimumSize(590, 470);`r`n    resize(620, 500);") | Out-Null
ReplaceLiteral $dialog '    root->setContentsMargins(24, 24, 24, 24);' '    root->setContentsMargins(26, 24, 26, 24);' | Out-Null
ReplaceLiteral $dialog '    root->setSpacing(14);' '    root->setSpacing(16);' | Out-Null
ReplaceLiteral $dialog '    m_avatar->setFixedSize(72, 72);' '    m_avatar->setFixedSize(76, 76);' | Out-Null
ReplaceLiteral $dialog '    m_avatar->setStyleSheet(QStringLiteral("border:1px solid palette(mid); border-radius:18px; font-size:28px;"));' '    m_avatar->setStyleSheet(QStringLiteral("background:#11241d;border:2px solid #2ce6a0;border-radius:38px;color:#8fffd1;font-size:24px;font-weight:800;"));' | Out-Null
ReplaceLiteral $dialog '    description->setStyleSheet(QStringLiteral("color: palette(mid);"));' '    description->setStyleSheet(QStringLiteral("color:#8fa99f;"));' | Out-Null
ReplaceLiteral $dialog '    m_code->setStyleSheet(QStringLiteral("padding:12px; border:1px solid palette(mid); border-radius:12px; font-size:18px;"));' '    m_code->setStyleSheet(QStringLiteral("padding:12px;background:#0b2119;border:1px solid #2d6f57;border-radius:12px;color:#a6ffda;font-size:18px;font-weight:700;"));' | Out-Null
ReplaceLiteral $dialog '    m_status->setStyleSheet(QStringLiteral("color: palette(mid);"));' '    m_status->setStyleSheet(QStringLiteral("color:#8fa99f;padding:4px 2px;"));' | Out-Null

$dialogText = [System.IO.File]::ReadAllText($dialog)
if (-not $dialogText.Contains('MCLauncher TrioSoft dialog theme')) {
    ReplaceRegex $dialog 'void TrioSoftIdDialog::buildUi\(\)\s*\{' (D 'dm9pZCBUcmlvU29mdElkRGlhbG9nOjpidWlsZFVpKCkKewogICAgLy8gTUNMYXVuY2hlciBUcmlvU29mdCBkaWFsb2cgdGhlbWUKICAgIHNldFN0eWxlU2hlZXQoUVN0cmluZ0xpdGVyYWwoIlFEaWFsb2d7YmFja2dyb3VuZDojMGEwZjBlO2NvbG9yOiNlZGY5ZjQ7fSBRTGFiZWx7Y29sb3I6I2RjZWNlNTt9IFFQdXNoQnV0dG9ue21pbi1oZWlnaHQ6MzRweDtwYWRkaW5nOjAgMTRweDtib3JkZXItcmFkaXVzOjlweDtiYWNrZ3JvdW5kOiMxNTFmMWM7Ym9yZGVyOjFweCBzb2xpZCAjMjk0NTNiO2NvbG9yOiNkY2VmZTc7Zm9udC13ZWlnaHQ6NzAwO30gUVB1c2hCdXR0b246aG92ZXJ7YmFja2dyb3VuZDojMWEzMDI4O2JvcmRlci1jb2xvcjojMzVkODlhO2NvbG9yOiNmZmZmZmY7fSBRUHVzaEJ1dHRvbjpwcmVzc2Vke2JhY2tncm91bmQ6IzEzMzMyNzt9IFFQdXNoQnV0dG9uOmRlZmF1bHR7YmFja2dyb3VuZDojMjJkOTkwO2JvcmRlci1jb2xvcjojMzVlZWE1O2NvbG9yOiMwNjExMGQ7fSBRUHVzaEJ1dHRvbjpkZWZhdWx0OmhvdmVye2JhY2tncm91bmQ6IzQ3ZWZhYztib3JkZXItY29sb3I6IzcxZmZjMDt9IFFQdXNoQnV0dG9uOmRpc2FibGVke2JhY2tncm91bmQ6IzEyMTgxNjtib3JkZXItY29sb3I6IzFmMmEyNjtjb2xvcjojNjI3MTY5O30iKSk7') | Out-Null
}

ReplaceRegex $dialog (D 'ICAgIGNvbnN0IFFTdHJpbmcgZGlzcGxheSA9ICFuYW1lXC5pc0VtcHR5XChcKSBcPyBuYW1lIDogLio/O1xyP1xu') (D 'ICAgIGNvbnN0IFFTdHJpbmcgZGlzcGxheSA9ICFuYW1lLmlzRW1wdHkoKSA/IG5hbWUgOiAoIXVzZXJuYW1lLmlzRW1wdHkoKSA/IHVzZXJuYW1lIDogdHIoItCf0L7Qu9GM0LfQvtCy0LDRgtC10LvRjCBUcmlvU29mdCIpKTsKICAgIG1fYXZhdGFyLT5zZXRQaXhtYXAoUVBpeG1hcCgpKTsKICAgIG1fYXZhdGFyLT5zZXRUZXh0KGRpc3BsYXkudHJpbW1lZCgpLmxlZnQoMikudG9VcHBlcigpKTsK') | Out-Null
ReplaceRegex $dialog (D 'ICAgIGNvbnN0IFFTdHJpbmcgcGljdHVyZSA9IHByb2ZpbGVcLnZhbHVlXChRU3RyaW5nTGl0ZXJhbFwoInBpY3R1cmUiXClcKVwudG9TdHJpbmdcKFwpO1xzKmlmIFwoIXBpY3R1cmVcLmlzRW1wdHlcKFwpXClccypsb2FkQXZhdGFyXChwaWN0dXJlXCk7') (D 'ICAgIGNvbnN0IFFTdHJpbmcgcGljdHVyZSA9IHByb2ZpbGUudmFsdWUoUVN0cmluZ0xpdGVyYWwoInBpY3R1cmUiKSkudG9TdHJpbmcoKTsKICAgIGlmICghcGljdHVyZS5pc0VtcHR5KCkpIHsKICAgICAgICBRVXJsIGF2YXRhclVybChwaWN0dXJlKTsKICAgICAgICBpZiAoYXZhdGFyVXJsLmlzUmVsYXRpdmUoKSkKICAgICAgICAgICAgYXZhdGFyVXJsID0ga0Jhc2VVcmwucmVzb2x2ZWQoYXZhdGFyVXJsKTsKICAgICAgICBsb2FkQXZhdGFyKGF2YXRhclVybC50b1N0cmluZygpKTsKICAgIH0=') | Out-Null

ReplaceLiteral $dialog '        m_premium->setStyleSheet(QStringLiteral("font-weight:700; color:#d6a928;"));' '        m_premium->setStyleSheet(QStringLiteral("background:#2b240d;border:1px solid #80661c;border-radius:9px;color:#ffd868;font-weight:800;padding:7px 11px;"));' | Out-Null
ReplaceLiteral $dialog '        m_premium->setStyleSheet(QString());' '        m_premium->setStyleSheet(QStringLiteral("background:#12211c;border:1px solid #29483d;border-radius:9px;color:#9fbab0;font-weight:800;padding:7px 11px;"));' | Out-Null
ReplaceLiteral $dialog '    m_premium->setStyleSheet(QString());' '    m_premium->setStyleSheet(QStringLiteral("background:#12211c;border:1px solid #29483d;border-radius:9px;color:#9fbab0;font-weight:800;padding:7px 11px;"));' | Out-Null

ReplaceRegex $dialog (D 'KD9zKXZvaWQgVHJpb1NvZnRJZERpYWxvZzo6bG9hZEF2YXRhclwoY29uc3QgUVN0cmluZyAmdXJsXClccypcey4qP1xyP1xuXH0=') (D 'dm9pZCBUcmlvU29mdElkRGlhbG9nOjpsb2FkQXZhdGFyKGNvbnN0IFFTdHJpbmcgJnVybCkKewogICAgUU5ldHdvcmtSZXF1ZXN0IHJlcXVlc3R7UVVybCh1cmwpfTsKICAgIHJlcXVlc3Quc2V0UmF3SGVhZGVyKCJBY2NlcHQiLCAiaW1hZ2UvYXZpZixpbWFnZS93ZWJwLGltYWdlL3BuZyxpbWFnZS9qcGVnLGltYWdlLyo7cT0wLjgsKi8qO3E9MC41Iik7CiAgICByZXF1ZXN0LnNldFJhd0hlYWRlcigiQ2FjaGUtQ29udHJvbCIsICJuby1jYWNoZSIpOwogICAgcmVxdWVzdC5zZXRSYXdIZWFkZXIoIlVzZXItQWdlbnQiLCAiTUNMYXVuY2hlci8xLjAuMCBUcmlvU29mdElEIik7CiAgICByZXF1ZXN0LnNldEF0dHJpYnV0ZShRTmV0d29ya1JlcXVlc3Q6OlJlZGlyZWN0UG9saWN5QXR0cmlidXRlLCBRTmV0d29ya1JlcXVlc3Q6Ok5vTGVzc1NhZmVSZWRpcmVjdFBvbGljeSk7CiAgICBhdXRvICpyZXBseSA9IG1fbmV0d29yay0+Z2V0KHJlcXVlc3QpOwogICAgY29ubmVjdChyZXBseSwgJlFOZXR3b3JrUmVwbHk6OmZpbmlzaGVkLCB0aGlzLCBbdGhpcywgcmVwbHldIHsKICAgICAgICBjb25zdCBRQnl0ZUFycmF5IGJ5dGVzID0gcmVwbHktPnJlYWRBbGwoKTsKICAgICAgICBjb25zdCBib29sIHN1Y2Nlc3MgPSByZXBseS0+ZXJyb3IoKSA9PSBRTmV0d29ya1JlcGx5OjpOb0Vycm9yOwogICAgICAgIHJlcGx5LT5kZWxldGVMYXRlcigpOwogICAgICAgIFFQaXhtYXAgcGl4bWFwOwogICAgICAgIGlmIChzdWNjZXNzICYmICFieXRlcy5pc0VtcHR5KCkgJiYgcGl4bWFwLmxvYWRGcm9tRGF0YShieXRlcykpIHsKICAgICAgICAgICAgbV9hdmF0YXItPnNldFRleHQoUVN0cmluZygpKTsKICAgICAgICAgICAgbV9hdmF0YXItPnNldFBpeG1hcChwaXhtYXAuc2NhbGVkKG1fYXZhdGFyLT5zaXplKCksIFF0OjpLZWVwQXNwZWN0UmF0aW9CeUV4cGFuZGluZywgUXQ6OlNtb290aFRyYW5zZm9ybWF0aW9uKSk7CiAgICAgICAgfQogICAgfSk7Cn0=') | Out-Null

$mainText = [System.IO.File]::ReadAllText($mainWindow)
if (-not $mainText.Contains('MCLauncher visual layer')) {
    ReplaceLiteral $mainWindow '    ui->setupUi(this);' (D 'ICAgIHVpLT5zZXR1cFVpKHRoaXMpOwoKICAgIC8vIE1DTGF1bmNoZXIgdmlzdWFsIGxheWVyCiAgICBzZXRTdHlsZVNoZWV0KHN0eWxlU2hlZXQoKSArIFFTdHJpbmdMaXRlcmFsKCJRTWFpbldpbmRvd3tiYWNrZ3JvdW5kOiMwYTBmMGU7Y29sb3I6I2VhZjhmMjt9IFFUb29sQmFye2JhY2tncm91bmQ6IzBlMTYxNDtib3JkZXI6bm9uZTtib3JkZXItYm90dG9tOjFweCBzb2xpZCAjMjAzNzJmO3NwYWNpbmc6NXB4O3BhZGRpbmc6NXB4IDdweDt9IFFUb29sQmFyIFFUb29sQnV0dG9ue2JhY2tncm91bmQ6dHJhbnNwYXJlbnQ7Ym9yZGVyOjFweCBzb2xpZCB0cmFuc3BhcmVudDtib3JkZXItcmFkaXVzOjhweDtjb2xvcjojZGNlZmU3O21hcmdpbjoxcHg7cGFkZGluZzo1cHggOHB4O30gUVRvb2xCYXIgUVRvb2xCdXR0b246aG92ZXJ7YmFja2dyb3VuZDojMTUzMzI5O2JvcmRlci1jb2xvcjojMmFjOThlO2NvbG9yOiNmZmZmZmY7fSBRVG9vbEJhciBRVG9vbEJ1dHRvbjpwcmVzc2VkLFFUb29sQmFyIFFUb29sQnV0dG9uOmNoZWNrZWR7YmFja2dyb3VuZDojMTk0MzMzO2JvcmRlci1jb2xvcjojMzVlOGE0O30gUVN0YXR1c0JhcntiYWNrZ3JvdW5kOiMwOTBlMGQ7Ym9yZGVyLXRvcDoxcHggc29saWQgIzFiMzAyOTtjb2xvcjojOGRhOTlmO30gUU1lbnV7YmFja2dyb3VuZDojMTAxODE2O2JvcmRlcjoxcHggc29saWQgIzI4NDQzYTtjb2xvcjojZThmNmYwO3BhZGRpbmc6NnB4O30gUU1lbnU6Oml0ZW17Ym9yZGVyLXJhZGl1czo2cHg7cGFkZGluZzo2cHggMjRweCA2cHggMTBweDt9IFFNZW51OjppdGVtOnNlbGVjdGVke2JhY2tncm91bmQ6IzE5NDUzNTtjb2xvcjojZmZmZmZmO30gUVB1c2hCdXR0b257YmFja2dyb3VuZDojMTUxZjFjO2JvcmRlcjoxcHggc29saWQgIzI5NDUzYjtib3JkZXItcmFkaXVzOjhweDtjb2xvcjojZGNlZmU3O21pbi1oZWlnaHQ6MjhweDtwYWRkaW5nOjNweCAxMHB4O30gUVB1c2hCdXR0b246aG92ZXJ7YmFja2dyb3VuZDojMWEzMDI4O2JvcmRlci1jb2xvcjojMzVkODlhO2NvbG9yOiNmZmZmZmY7fSBRTGluZUVkaXQsUUNvbWJvQm94LFFTcGluQm94LFFEb3VibGVTcGluQm94LFFUZXh0RWRpdCxRUGxhaW5UZXh0RWRpdHtiYWNrZ3JvdW5kOiMwZjE3MTU7Ym9yZGVyOjFweCBzb2xpZCAjMjk0NTNiO2JvcmRlci1yYWRpdXM6N3B4O2NvbG9yOiNlYWY4ZjI7c2VsZWN0aW9uLWJhY2tncm91bmQtY29sb3I6IzIxODg1ZjtwYWRkaW5nOjRweCA3cHg7fSBRVHJlZVZpZXcsUUxpc3RWaWV3LFFUYWJsZVZpZXd7YmFja2dyb3VuZDojMGQxNDEyO2FsdGVybmF0ZS1iYWNrZ3JvdW5kLWNvbG9yOiMxMDE5MTY7Ym9yZGVyOjFweCBzb2xpZCAjMWYzNTJkO2NvbG9yOiNkYmVjZTU7c2VsZWN0aW9uLWJhY2tncm91bmQtY29sb3I6IzFiNjA0NztzZWxlY3Rpb24tY29sb3I6I2ZmZmZmZjt9IFFIZWFkZXJWaWV3OjpzZWN0aW9ue2JhY2tncm91bmQ6IzExMWIxODtib3JkZXI6bm9uZTtib3JkZXItcmlnaHQ6MXB4IHNvbGlkICMyMDM3MmY7Ym9yZGVyLWJvdHRvbToxcHggc29saWQgIzIwMzcyZjtjb2xvcjojYTljMWI4O3BhZGRpbmc6NXB4O30gUVNjcm9sbEJhcjp2ZXJ0aWNhbCxRU2Nyb2xsQmFyOmhvcml6b250YWx7YmFja2dyb3VuZDojMGIxMTEwO2JvcmRlcjpub25lO21hcmdpbjowO30gUVNjcm9sbEJhcjo6aGFuZGxlOnZlcnRpY2FsLFFTY3JvbGxCYXI6OmhhbmRsZTpob3Jpem9udGFse2JhY2tncm91bmQ6IzMxNTM0Nztib3JkZXItcmFkaXVzOjVweDttaW4taGVpZ2h0OjIycHg7bWluLXdpZHRoOjIycHg7fSBRU2Nyb2xsQmFyOjpoYW5kbGU6dmVydGljYWw6aG92ZXIsUVNjcm9sbEJhcjo6aGFuZGxlOmhvcml6b250YWw6aG92ZXJ7YmFja2dyb3VuZDojM2M4MDY3O30gUVNjcm9sbEJhcjo6YWRkLWxpbmUsUVNjcm9sbEJhcjo6c3ViLWxpbmV7d2lkdGg6MHB4O2hlaWdodDowcHg7fSIpKTsKICAgIHVpLT5tYWluVG9vbEJhci0+c2V0SWNvblNpemUoUVNpemUoMjAsIDIwKSk7') | Out-Null
}

$oldBrand = D 'TUNMYXVuY2hlciBieSBUcmlvU29mdCDCtyB0cmlvc29mdC54eXo='
ReplaceLiteral $mainWindow $oldBrand 'MCLauncher by TrioSoft | triosoft.xyz' | Out-Null

$checks = @(
    @($buildConfig, 'VERSION_CHANNEL = "stable";'),
    @($application, 'BuildConfig.versionString()'),
    @($dialog, 'kBaseUrl.resolved(avatarUrl)'),
    @($dialog, 'NoLessSafeRedirectPolicy'),
    @($dialog, 'MCLauncher TrioSoft dialog theme'),
    @($mainWindow, 'MCLauncher visual layer')
)

foreach ($check in $checks) {
    $body = [System.IO.File]::ReadAllText([string]$check[0])
    if (-not $body.Contains([string]$check[1])) {
        throw ('UI fix validation failed: ' + [string]$check[1])
    }
}

Write-Host 'MCLauncher UI fixes applied successfully.' -ForegroundColor Green
