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
$dialogTarget = Join-Path $Source 'launcher\ui\dialogs\TrioSoftIdDialog.cpp'
$themeSource = Join-Path $Root 'TrioSoftTheme.h'
$themeTarget = Join-Path $Source 'launcher\ui\themes\TrioSoftTheme.h'
$dialogPayload = Join-Path $Root 'assets\TrioSoftIdDialog.cpp.gz.b64'

foreach ($path in @($buildConfig, $application, $mainWindow, $themeSource, $dialogPayload)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw ('Required file is missing: ' + $path)
    }
}

Write-Host '==> Applying TrioSoft App Hub design system to MCLauncher' -ForegroundColor Cyan

# Release version stays exactly 1.0.0.
ReplaceRegex $buildConfig (D 'KD9zKSAgICBpZiBcKEdJVF9SRUZTUEVDXC5zdGFydHNXaXRoXCgicmVmcy9oZWFkcy8iXClcKSBcey4qP1ZFUlNJT05fQ0hBTk5FTCA9ICJ1bmtub3duIjtccyogICAgXH0=') (D 'DQogICAgVkVSU0lPTl9DSEFOTkVMID0gInN0YWJsZSI7DQogICAgR0lUX1RBRyA9IHZlcnNpb25TdHJpbmcoKTs=') | Out-Null
ReplaceRegex $buildConfig (D 'KD9zKVFTdHJpbmcgQ29uZmlnOjpwcmludGFibGVWZXJzaW9uU3RyaW5nXChcKSBjb25zdFxzKlx7Lio/XHI/XG5cfQ==') (D 'UVN0cmluZyBDb25maWc6OnByaW50YWJsZVZlcnNpb25TdHJpbmcoKSBjb25zdA0Kew0KICAgIHJldHVybiB2ZXJzaW9uU3RyaW5nKCk7DQp9') | Out-Null
ReplaceLiteral $application 'BuildConfig.printableVersionString()' 'BuildConfig.versionString()' | Out-Null

# Install the global theme copied from the TrioSoft App Hub design tokens.
Copy-Item -LiteralPath $themeSource -Destination $themeTarget -Force
$appText = [System.IO.File]::ReadAllText($application)
if (-not $appText.Contains('ui/themes/TrioSoftTheme.h')) {
    ReplaceLiteral $application (D 'I2luY2x1ZGUgInVpL3RoZW1lcy9UaGVtZU1hbmFnZXIuaCI=') (D 'I2luY2x1ZGUgInVpL3RoZW1lcy9UaGVtZU1hbmFnZXIuaCINCiNpbmNsdWRlICJ1aS90aGVtZXMvVHJpb1NvZnRUaGVtZS5oIg==') | Out-Null
}
$appText = [System.IO.File]::ReadAllText($application)
if (-not $appText.Contains('TrioSoftTheme::styleSheet()')) {
    ReplaceLiteral $application (D 'ICAgIHNldERlc2t0b3BGaWxlTmFtZShCdWlsZENvbmZpZy5MQVVOQ0hFUl9BUFBJRCk7') (D 'ICAgIHNldERlc2t0b3BGaWxlTmFtZShCdWlsZENvbmZpZy5MQVVOQ0hFUl9BUFBJRCk7DQoNCiAgICAvLyBUcmlvU29mdCBBcHAgSHViIHZpc3VhbCBzeXN0ZW0uDQogICAgc2V0U3R5bGUoUVN0eWxlRmFjdG9yeTo6Y3JlYXRlKFFTdHJpbmdMaXRlcmFsKCJGdXNpb24iKSkpOw0KICAgIHNldFN0eWxlU2hlZXQoVHJpb1NvZnRUaGVtZTo6c3R5bGVTaGVldCgpKTs=') | Out-Null
}

# Remove the old temporary green-only skin if it exists.
ReplaceRegex $mainWindow (D 'KD9zKVxyP1xuXHMqLy8gTUNMYXVuY2hlciB2aXN1YWwgbGF5ZXIuKj91aS0+bWFpblRvb2xCYXItPnNldEljb25TaXplXChRU2l6ZVwoMjAsIDIwXClcKTtccj9cbg==') (D 'DQo=') | Out-Null

# Write a known-good TrioSoft ID dialog instead of trying to patch C++ with PowerShell quoting.
$payloadText = [System.IO.File]::ReadAllText($dialogPayload).Trim()
$compressed = [System.Convert]::FromBase64String($payloadText)
$memory = New-Object System.IO.MemoryStream(,$compressed)
$gzip = New-Object System.IO.Compression.GZipStream($memory, [System.IO.Compression.CompressionMode]::Decompress)
$reader = New-Object System.IO.StreamReader($gzip, [System.Text.Encoding]::UTF8)
try {
    $dialogText = $reader.ReadToEnd()
} finally {
    $reader.Dispose()
    $gzip.Dispose()
    $memory.Dispose()
}
WriteUtf8 $dialogTarget $dialogText

# Clean footer separator if the old centered-dot string is present.
$mainBody = [System.IO.File]::ReadAllText($mainWindow)
$oldBrand = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('TUNMYXVuY2hlciBieSBUcmlvU29mdCDCtyB0cmlvc29mdC54eXo='))
if ($mainBody.Contains($oldBrand)) {
    WriteUtf8 $mainWindow ($mainBody.Replace($oldBrand, 'MCLauncher by TrioSoft | triosoft.xyz'))
}

$checks = @(
    @($buildConfig, 'VERSION_CHANNEL = "stable";'),
    @($application, 'ui/themes/TrioSoftTheme.h'),
    @($application, 'TrioSoftTheme::styleSheet()'),
    @($dialogTarget, 'kBaseUrl.resolved(avatarUrl)'),
    @($dialogTarget, 'TrioSoftID/avatarBytes'),
    @($dialogTarget, 'TrioSoft App Hub /account visual language')
)
foreach ($check in $checks) {
    $body = [System.IO.File]::ReadAllText([string]$check[0])
    if (-not $body.Contains([string]$check[1])) {
        throw ('TrioSoft UI validation failed: ' + [string]$check[1])
    }
}

Write-Host 'MCLauncher now uses the TrioSoft App Hub visual system.' -ForegroundColor Green
