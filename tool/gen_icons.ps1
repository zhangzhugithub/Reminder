# Generate placeholder app icons (Android mipmaps + iOS AppIcon 1024).
# Placeholder clock icons generated with .NET System.Drawing.
# Replace with real design assets before release (keep the same file names).
# Usage: powershell -ExecutionPolicy Bypass -File tool\gen_icons.ps1

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$teal = [System.Drawing.Color]::FromArgb(255, 0, 137, 123)
$white = [System.Drawing.Color]::White
$hand = [System.Drawing.Color]::FromArgb(255, 0, 90, 80)

function New-AppIcon([int]$size, [string]$path) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $g.FillRectangle((New-Object System.Drawing.SolidBrush($teal)), 0, 0, $size, $size)

    $cx = $size / 2.0
    $cy = $size / 2.0
    $r = $size * 0.34
    $g.FillEllipse((New-Object System.Drawing.SolidBrush($white)), [float]($cx - $r), [float]($cy - $r), [float]($r * 2), [float]($r * 2))

    $penW = [Math]::Max(1.0, $size * 0.035)
    $pen = New-Object System.Drawing.Pen($hand, [float]$penW)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($pen, [float]$cx, [float]$cy, [float]($cx - $r * 0.45), [float]($cy - $r * 0.45))
    $g.DrawLine($pen, [float]$cx, [float]$cy, [float]($cx + $r * 0.55), [float]($cy - $r * 0.3))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush($hand)), [float]($cx - $penW * 0.8), [float]($cy - $penW * 0.8), [float]($penW * 1.6), [float]($penW * 1.6))

    $pen.Dispose()
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "generated: $path"
}

$mipmapSizes = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($density in $mipmapSizes.Keys) {
    $dir = Join-Path $projectRoot ("android\app\src\main\res\mipmap-" + $density)
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    New-AppIcon $mipmapSizes[$density] (Join-Path $dir 'ic_launcher.png')
}

$iosDir = Join-Path $projectRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
New-Item -ItemType Directory -Force -Path $iosDir | Out-Null
New-AppIcon 1024 (Join-Path $iosDir 'icon-1024.png')

Write-Host 'done.'
