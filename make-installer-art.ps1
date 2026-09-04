$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogoPath = Join-Path $Root 'mclauncher-256.png'
$WelcomePath = Join-Path $Root 'mclauncher-welcome.bmp'
$HeaderPath = Join-Path $Root 'mclauncher-header.bmp'

if (-not (Test-Path -LiteralPath $LogoPath -PathType Leaf)) {
    throw "MCLauncher logo was not found: $LogoPath. Run START.cmd first."
}

Add-Type -AssemblyName System.Drawing

function New-McFont {
    param(
        [Parameter(Mandatory=$true)][float]$Size,
        [Parameter(Mandatory=$true)][System.Drawing.FontStyle]$Style
    )

    return [System.Drawing.Font]::new(
        [string]'Segoe UI',
        [single]$Size,
        [System.Drawing.FontStyle]$Style,
        [System.Drawing.GraphicsUnit]::Pixel
    )
}

function New-WelcomeBitmap {
    param([System.Drawing.Image]$Logo)

    $bitmap = [System.Drawing.Bitmap]::new(164, 314)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 0))

        $rect = [System.Drawing.Rectangle]::new(0, 0, 164, 314)
        $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $rect,
            [System.Drawing.Color]::FromArgb(4, 5, 8),
            [System.Drawing.Color]::FromArgb(14, 18, 34),
            [single]90.0
        )
        try { $graphics.FillRectangle($gradient, $rect) } finally { $gradient.Dispose() }

        $glow = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(46, 10, 120, 238))
        try { $graphics.FillEllipse($glow, -28, 32, 220, 220) } finally { $glow.Dispose() }

        $graphics.DrawImage($Logo, 16, 56, 132, 132)

        $accent = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(10, 120, 238))
        try { $graphics.FillRectangle($accent, 18, 230, 128, 4) } finally { $accent.Dispose() }

        $titleFont = New-McFont -Size 18 -Style ([System.Drawing.FontStyle]::Bold)
        $smallFont = New-McFont -Size 12 -Style ([System.Drawing.FontStyle]::Regular)
        $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(242, 244, 248))
        $muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(162, 166, 176))
        try {
            $graphics.DrawString('MCLauncher', $titleFont, $white, [single]18, [single]246)
            $graphics.DrawString('by TrioSoft', $smallFont, $muted, [single]18, [single]274)
        } finally {
            $titleFont.Dispose()
            $smallFont.Dispose()
            $white.Dispose()
            $muted.Dispose()
        }

        $bitmap.Save($WelcomePath, [System.Drawing.Imaging.ImageFormat]::Bmp)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function New-HeaderBitmap {
    param([System.Drawing.Image]$Logo)

    $bitmap = [System.Drawing.Bitmap]::new(150, 57)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 0))

        $rect = [System.Drawing.Rectangle]::new(0, 0, 150, 57)
        $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            $rect,
            [System.Drawing.Color]::FromArgb(5, 6, 9),
            [System.Drawing.Color]::FromArgb(20, 24, 44),
            [single]0.0
        )
        try { $graphics.FillRectangle($gradient, $rect) } finally { $gradient.Dispose() }

        $graphics.DrawImage($Logo, 98, 4, 48, 48)

        $titleFont = New-McFont -Size 13 -Style ([System.Drawing.FontStyle]::Bold)
        $smallFont = New-McFont -Size 10 -Style ([System.Drawing.FontStyle]::Regular)
        $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(242, 244, 248))
        $accent2 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(107, 104, 245))
        try {
            $graphics.DrawString('MCLauncher', $titleFont, $white, [single]8, [single]9)
            $graphics.DrawString('TrioSoft', $smallFont, $accent2, [single]8, [single]30)
        } finally {
            $titleFont.Dispose()
            $smallFont.Dispose()
            $white.Dispose()
            $accent2.Dispose()
        }

        $bitmap.Save($HeaderPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$logo = [System.Drawing.Image]::FromFile($LogoPath)
try {
    New-WelcomeBitmap -Logo $logo
    New-HeaderBitmap -Logo $logo
} finally {
    $logo.Dispose()
}

if (-not (Test-Path -LiteralPath $WelcomePath -PathType Leaf)) {
    throw "Installer welcome bitmap was not created: $WelcomePath"
}
if (-not (Test-Path -LiteralPath $HeaderPath -PathType Leaf)) {
    throw "Installer header bitmap was not created: $HeaderPath"
}

Write-Host "Installer branding ready: $WelcomePath" -ForegroundColor Green
Write-Host "Installer header ready: $HeaderPath" -ForegroundColor Green
