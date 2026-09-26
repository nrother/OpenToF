# Derives all app branding images (Windows only, System.Drawing).
# Run: powershell -File tool/generate_branding.ps1
# Then: dart run flutter_launcher_icons ; dart run flutter_native_splash:create
#
# Sources (shared branding, repo root img/):
#   img/opentof-logo.png            the logo: stopwatch + jumper + trampoline, blue #0153E3 with a red bed marking,
#                                   transparent background, opaque white bed (source: img/opentof-logo.svg)
#   img/OpenToF_Wordmark_logo.png   "OPENT<logo>F" wordmark (built by img/make_wordmark.py)
#   img/opentof-logo-dark.png, img/OpenToF_Wordmark_logo_dark.png   dark-theme versions (same script)
# Outputs: see the sections below.
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
public static class Glyph {
  // Turns the logo into a single-colour glyph mask for white/monochrome icons: the opaque white
  // trampoline bed becomes a hole instead of part of the silhouette. `px` is BGRA, modified in place.
  public static void KnockOutWhite(byte[] px) {
    for (int i = 0; i < px.Length; i += 4) {
      int min = Math.Min(px[i], Math.Min(px[i + 1], px[i + 2]));
      if (min <= 200) continue;
      double t = (min - 200) / 55.0; // 0 at light grey .. 1 at pure white
      px[i + 3] = (byte)Math.Round(px[i + 3] * (1 - t));
    }
  }
}
'@

$root = Split-Path -Parent $PSScriptRoot
$img = Join-Path (Split-Path -Parent $root) 'img'
New-Item -ItemType Directory -Force "$root\assets\branding" | Out-Null

function New-Canvas([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  return @{ Bitmap = $bmp; Graphics = $g }
}

function Save-Png($canvas, [string]$path) {
  $canvas.Graphics.Dispose()
  New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
  $canvas.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $canvas.Bitmap.Dispose()
}

# Crops a bitmap to its non-transparent pixels.
function Crop-ToContent($bmp) {
  $minX = $bmp.Width; $minY = $bmp.Height; $maxX = 0; $maxY = 0
  for ($y = 0; $y -lt $bmp.Height; $y += 1) {
    for ($x = 0; $x -lt $bmp.Width; $x += 1) {
      if ($bmp.GetPixel($x, $y).A -gt 0) {
        if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  $rect = New-Object System.Drawing.Rectangle $minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1)
  return $bmp.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

# ---------------------------------------------------------------------------------------------
# A) Wordmark for the Settings header (light + dark theme): "OPENT<logo>F", scaled to 1200 px wide.
# ---------------------------------------------------------------------------------------------
foreach ($v in @(@('', ''), @('_dark', '_dark'))) {
  $wm = New-Object System.Drawing.Bitmap "$img\OpenToF_Wordmark_logo$($v[0]).png"
  $wmW = 1200; $wmH = [int][math]::Round($wmW * $wm.Height / $wm.Width)
  $c = New-Canvas $wmW $wmH
  $c.Graphics.DrawImage($wm, 0, 0, $wmW, $wmH)
  Save-Png $c "$root\assets\images\OpenToF_wordmark$($v[1]).png"
  $wm.Dispose()
}

# ---------------------------------------------------------------------------------------------
# B) The logo as the mark (small sizes): cropped to the artwork; a glyph copy for white icons.
# ---------------------------------------------------------------------------------------------
$raw = New-Object System.Drawing.Bitmap "$img\opentof-logo.png"
$mark = Crop-ToContent $raw
$raw.Dispose()
$raw = New-Object System.Drawing.Bitmap "$img\opentof-logo-dark.png"
$darkMark = Crop-ToContent $raw
$raw.Dispose()

$glyph = $mark.Clone((New-Object System.Drawing.Rectangle 0, 0, $mark.Width, $mark.Height), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$rect = New-Object System.Drawing.Rectangle 0, 0, $glyph.Width, $glyph.Height
$data = $glyph.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($data.Stride * $glyph.Height)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
[Glyph]::KnockOutWhite($bytes)
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
$glyph.UnlockBits($data)

# Draws the mark centered at (cx, cy) with the given height; -White paints the glyph pure white,
# -Dark uses the dark-theme logo.
function Draw-Mark($g, [double]$cx, [double]$cy, [double]$height, [switch]$White, [switch]$Dark) {
  $src = if ($White) { $glyph } elseif ($Dark) { $darkMark } else { $mark }
  $width = $height * $src.Width / $src.Height
  $dest = New-Object System.Drawing.Rectangle ([int][math]::Round($cx - $width / 2)), ([int][math]::Round($cy - $height / 2)), ([int][math]::Round($width)), ([int][math]::Round($height))
  $attr = New-Object System.Drawing.Imaging.ImageAttributes
  $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
  if ($White) {
    $m = New-Object System.Drawing.Imaging.ColorMatrix
    $m.Matrix00 = 0; $m.Matrix11 = 0; $m.Matrix22 = 0; $m.Matrix33 = 1
    $m.Matrix40 = 1; $m.Matrix41 = 1; $m.Matrix42 = 1; $m.Matrix44 = 1
    $attr.SetColorMatrix($m)
  }
  $g.DrawImage($src, $dest, 0, 0, $src.Width, $src.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr)
}

# 1) In-app mark (app bar): transparent, cropped tightly, 512 px tall; light and dark theme.
$c = New-Canvas ([int][math]::Round(512 * $mark.Width / $mark.Height)) 512
Draw-Mark $c.Graphics ($c.Bitmap.Width / 2) 256 512
Save-Png $c "$root\assets\images\OpenToF_mark.png"
$c = New-Canvas ([int][math]::Round(512 * $darkMark.Width / $darkMark.Height)) 512
Draw-Mark $c.Graphics ($c.Bitmap.Width / 2) 256 512 -Dark
Save-Png $c "$root\assets\images\OpenToF_mark_dark.png"

# 2) iOS / legacy Android icon: opaque white square (iOS rejects alpha), mark 70 % of the height.
$c = New-Canvas 1024 1024
$c.Graphics.Clear([System.Drawing.Color]::White)
Draw-Mark $c.Graphics 512 512 720
Save-Png $c "$root\assets\branding\app_icon.png"

# 3) Android adaptive foreground (transparent; the visible area is a ~66 % circle) + monochrome (themed icon).
$c = New-Canvas 1024 1024
Draw-Mark $c.Graphics 512 512 600
Save-Png $c "$root\assets\branding\app_icon_foreground.png"
$c = New-Canvas 1024 1024
Draw-Mark $c.Graphics 512 512 600 -White
Save-Png $c "$root\assets\branding\app_icon_monochrome.png"

# 4) Splash (Android < 12 / iOS): transparent; the dark version is shown on the dark splash background.
$c = New-Canvas 1152 1152
Draw-Mark $c.Graphics 576 576 640
Save-Png $c "$root\assets\branding\splash_logo.png"
$c = New-Canvas 1152 1152
Draw-Mark $c.Graphics 576 576 640 -Dark
Save-Png $c "$root\assets\branding\splash_logo_dark.png"

# 5) Android 12+ splash icon: the OS masks it with a circle of 2/3 of the canvas.
$c = New-Canvas 1152 1152
Draw-Mark $c.Graphics 576 576 560
Save-Png $c "$root\assets\branding\splash_android12.png"
$c = New-Canvas 1152 1152
Draw-Mark $c.Graphics 576 576 560 -Dark
Save-Png $c "$root\assets\branding\splash_android12_dark.png"

# 6) Android status-bar (notification) icon: white glyph, 24 dp at each density (sizes 24/36/48/72/96 px).
foreach ($d in @(@('mdpi', 24), @('hdpi', 36), @('xhdpi', 48), @('xxhdpi', 72), @('xxxhdpi', 96))) {
  $size = $d[1]
  $c = New-Canvas $size $size
  Draw-Mark $c.Graphics ($size / 2) ($size / 2) ($size - 2) -White
  Save-Png $c "$root\android\app\src\main\res\drawable-$($d[0])\ic_stat_opentof.png"
}

$mark.Dispose()
$darkMark.Dispose()
$glyph.Dispose()
"done"
