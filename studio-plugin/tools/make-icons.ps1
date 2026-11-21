param([Parameter(Mandatory = $true)][string]$Source)
# Builds the plugin icons from the logo (any WIC-readable image with alpha, e.g. WebP/PNG):
#   assets/logo.png         cropped transparent logo, 512px
#   assets/icon-<n>.png     white logo on a dark rounded square (visible in light and dark Studio themes)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore, WindowsBase
$out = Join-Path (Split-Path $PSScriptRoot -Parent) 'assets'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$decoder = [Windows.Media.Imaging.BitmapDecoder]::Create([Uri](Resolve-Path $Source).Path, 'None', 'OnLoad')
$bitmap = New-Object Windows.Media.Imaging.FormatConvertedBitmap($decoder.Frames[0], [Windows.Media.PixelFormats]::Bgra32, $null, 0)
$w = $bitmap.PixelWidth; $h = $bitmap.PixelHeight
$px = New-Object byte[] ($w * $h * 4)
$bitmap.CopyPixels($px, $w * 4, 0)

# Crop to the visible logo, then square it.
$x0 = $w; $y0 = $h; $x1 = 0; $y1 = 0
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        if ($px[($y * $w + $x) * 4 + 3] -gt 16) {
            if ($x -lt $x0) { $x0 = $x }; if ($x -gt $x1) { $x1 = $x }
            if ($y -lt $y0) { $y0 = $y }; if ($y -gt $y1) { $y1 = $y }
        }
    }
}
$side = [Math]::Max($x1 - $x0, $y1 - $y0) + 1
$cx = ($x0 + $x1) / 2; $cy = ($y0 + $y1) / 2
$crop = New-Object Windows.Rect(($cx - $side / 2), ($cy - $side / 2), $side, $side)

function Save-Png($source, $path) {
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($source))
    $stream = [IO.File]::Create($path)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
}
function Render([int]$size, [bool]$tile) {
    $visual = New-Object Windows.Media.DrawingVisual
    [Windows.Media.RenderOptions]::SetBitmapScalingMode($visual, 'HighQuality')
    $dc = $visual.RenderOpen()
    $logoSize = $size
    if ($tile) {
        $radius = $size * 0.22
        $brush = New-Object Windows.Media.SolidColorBrush([Windows.Media.Color]::FromRgb(22, 25, 35))
        $dc.DrawRoundedRectangle($brush, $null, (New-Object Windows.Rect(0, 0, $size, $size)), $radius, $radius)
        $logoSize = $size * 0.74
    }
    $offset = ($size - $logoSize) / 2
    $dc.PushClip((New-Object Windows.Media.RectangleGeometry((New-Object Windows.Rect($offset, $offset, $logoSize, $logoSize)))))
    $scale = $logoSize / $side
    $dc.DrawImage($bitmap, (New-Object Windows.Rect(($offset - $crop.X * $scale), ($offset - $crop.Y * $scale), ($w * $scale), ($h * $scale))))
    $dc.Pop()
    $dc.Close()
    $target = New-Object Windows.Media.Imaging.RenderTargetBitmap($size, $size, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
    $target.Render($visual)
    return $target
}

Save-Png (Render 512 $false) (Join-Path $out 'logo.png')
foreach ($size in 16, 32, 64, 128, 256) { Save-Png (Render $size $true) (Join-Path $out "icon-$size.png") }
Write-Output "Icons written to $out (logo crop ${side}px)"
