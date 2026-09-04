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

function New-WelcomeBitmap {
    param([System.Drawing.Image]$Logo)
    $bitmap = New-Object System.Drawing.Bitmap 164,314
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.Clear([System.Drawing.Color]::FromArgb(5,12,10))
        $rect = New-Object System.Drawing.Rectangle 0,0,164,314
        $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,[System.Drawing.Color]::FromArgb(6,14,12),[System.Drawing.Color]::FromArgb(8,32,24),90.0)
        try { $graphics.FillRectangle($gradient, $rect) } finally { $gradient.Dispose() }
        $glow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(34,32,235,157))
        try { $graphics.FillEllipse($glow, -28, 36, 220, 220) } finally { $glow.Dispose() }
        $graphics.DrawImage($Logo, 16, 56, 132, 132)
        $accent = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(39,235,158))
        try { $graphics.FillRectangle($accent, 18, 230, 128, 4) } finally { $accent.Dispose() }
        $titleFont = New-Object System.Drawing.Font 'Segoe UI',14,[System.Drawing.FontStyle]::Bold
        $smallFont = New-Object System.Drawing.Font 'Segoe UI',9,[System.Drawing.FontStyle]::Regular
        $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(239,255,248))
        $muted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(125,191,166))
        try {
            $graphics.DrawString('MCLauncher', $titleFont, $white, 18, 246)
            $graphics.DrawString('by TrioSoft', $smallFont, $muted, 18, 274)
        } finally {
            $titleFont.Dispose(); $smallFont.Dispose(); $white.Dispose(); $muted.Dispose()
        }
        $bitmap.Save($WelcomePath, [System.Drawing.Imaging.ImageFormat]::Bmp)
    } finally {
        $graphics.Dispose(); $bitmap.Dispose()
    }
}

function New-HeaderBitmap {
    param([System.Drawing.Image]$Logo)
    $bitmap = New-Object System.Drawing.Bitmap 150,57
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.Clear([System.Drawing.Color]::FromArgb(6,15,12))
        $rect = New-Object System.Drawing.Rectangle 0,0,150,57
        $gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,[System.Drawing.Color]::FromArgb(6,15,12),[System.Drawing.Color]::FromArgb(12,45,33),0.0)
        try { $graphics.FillRectangle($gradient, $rect) } finally { $gradient.Dispose() }
        $graphics.DrawImage($Logo, 98, 4, 48, 48)
        $titleFont = New-Object System.Drawing.Font 'Segoe UI',10,[System.Drawing.FontStyle]::Bold
        $smallFont = New-Object System.Drawing.Font 'Segoe UI',8,[System.Drawing.FontStyle]::Regular
        $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(240,255,249))
        $green = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(45,238,163))
        try {
            $graphics.DrawString('MCLauncher', $titleFont, $white, 8, 9)
            $graphics.DrawString('TrioSoft', $smallFont, $green, 8, 30)
        } finally {
            $titleFont.Dispose(); $smallFont.Dispose(); $white.Dispose(); $green.Dispose()
        }
        $bitmap.Save($HeaderPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
    } finally {
        $graphics.Dispose(); $bitmap.Dispose()
    }
}

$logo = [System.Drawing.Image]::FromFile($LogoPath)
try {
    New-WelcomeBitmap -Logo $logo
    New-HeaderBitmap -Logo $logo
} finally {
    $logo.Dispose()
}

Write-Host "Installer branding ready: $WelcomePath" -ForegroundColor Green
Write-Host "Installer header ready: $HeaderPath" -ForegroundColor Green
