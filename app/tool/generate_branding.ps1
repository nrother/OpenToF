# Derives all branding images (Windows only, System.Drawing).
# Run: powershell -File tool/generate_branding.ps1
# Then: dart run flutter_launcher_icons ; dart run flutter_native_splash:create
#
# Sources:
#   assets/branding/app_icon2.png   new mark (single blue on a uniform dark background, 1254x1254)
#   assets/images/OpenToF_logo.png  old wordmark logo (still used as the large logo in Settings)
# Outputs: see the sections below.
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
public static class MarkExtractor {
  // Turns "one foreground color on a uniform background" into that color with an alpha channel:
  // pixel = a*fg + (1-a)*bg, so anti-aliased edges keep their softness. `px` is BGRA, modified in place.
  // Returns { minX, minY, maxX, maxY, fgR, fgG, fgB, bgR, bgG, bgB }.
  public static int[] Extract(byte[] px, int w, int h) {
    double br = 0, bgc = 0, bb = 0; int n = 0;
    int[][] corners = { new[]{0,0}, new[]{w-8,0}, new[]{0,h-8}, new[]{w-8,h-8} };
    foreach (var c in corners)
      for (int y = c[1]; y < c[1] + 8; y++)
        for (int x = c[0]; x < c[0] + 8; x++) {
          int i = (y * w + x) * 4;
          bb += px[i]; bgc += px[i + 1]; br += px[i + 2]; n++;
        }
    br /= n; bgc /= n; bb /= n;

    double max = 0;
    for (int i = 0; i < px.Length; i += 4) {
      double d = Dist(px[i + 2] - br, px[i + 1] - bgc, px[i] - bb);
      if (d > max) max = d;
    }
    // Foreground = the most common color among the pixels far from the background
    // (the extreme pixels alone would be a highlight, not the body color).
    var counts = new System.Collections.Generic.Dictionary<int, int>();
    for (int i = 0; i < px.Length; i += 4) {
      double d = Dist(px[i + 2] - br, px[i + 1] - bgc, px[i] - bb);
      if (d < 0.8 * max) continue;
      int key = ((px[i + 2] >> 3) << 10) | ((px[i + 1] >> 3) << 5) | (px[i] >> 3);
      int cnt; counts.TryGetValue(key, out cnt); counts[key] = cnt + 1;
    }
    int best = 0, bestCount = -1;
    foreach (var kv in counts) if (kv.Value > bestCount) { best = kv.Key; bestCount = kv.Value; }
    double fr = 0, fg = 0, fb = 0; int fn = 0;
    for (int i = 0; i < px.Length; i += 4) {
      int key = ((px[i + 2] >> 3) << 10) | ((px[i + 1] >> 3) << 5) | (px[i] >> 3);
      if (key == best) { fr += px[i + 2]; fg += px[i + 1]; fb += px[i]; fn++; }
    }
    fr /= fn; fg /= fn; fb /= fn;

    double vr = fr - br, vg = fg - bgc, vb = fb - bb, vv = vr * vr + vg * vg + vb * vb;
    int minX = w, minY = h, maxX = 0, maxY = 0;
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++) {
        int i = (y * w + x) * 4;
        double t = ((px[i + 2] - br) * vr + (px[i + 1] - bgc) * vg + (px[i] - bb) * vb) / vv;
        if (t < 0.04) t = 0; else if (t > 0.96) t = 1;
        px[i] = (byte)Math.Round(fb); px[i + 1] = (byte)Math.Round(fg); px[i + 2] = (byte)Math.Round(fr);
        px[i + 3] = (byte)Math.Round(t * 255);
        if (t > 0.5) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
      }
    return new[]{ minX, minY, maxX, maxY, (int)Math.Round(fr), (int)Math.Round(fg), (int)Math.Round(fb),
                  (int)Math.Round(br), (int)Math.Round(bgc), (int)Math.Round(bb) };
  }
  static double Dist(double a, double b, double c) { return Math.Sqrt(a * a + b * b + c * c); }
}
'@

$root = Split-Path -Parent $PSScriptRoot
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

# ---------------------------------------------------------------------------------------------
# A) Old wordmark logo (large logo in Settings): subtitle cropped off, near-white snapped to white.
# ---------------------------------------------------------------------------------------------
$orig = [System.Drawing.Image]::FromFile("$root\assets\images\OpenToF_logo.png")
$wm = New-Object System.Drawing.Bitmap $orig
$orig.Dispose()
$wmCropH = 442 # in the 546x478 source the wordmark ends at row 437, the subtitle starts at row 445
for ($y = 0; $y -lt $wm.Height; $y++) {
  for ($x = 0; $x -lt $wm.Width; $x++) {
    $p = $wm.GetPixel($x, $y)
    if ($p.R -ge 240 -and $p.G -ge 240 -and $p.B -ge 240) { $wm.SetPixel($x, $y, [System.Drawing.Color]::White) }
  }
}
$c = New-Canvas $wm.Width $wmCropH
$c.Graphics.DrawImage($wm, (New-Object System.Drawing.RectangleF 0, 0, $wm.Width, $wmCropH),
  (New-Object System.Drawing.RectangleF 0, 0, $wm.Width, $wmCropH), [System.Drawing.GraphicsUnit]::Pixel)
Save-Png $c "$root\assets\images\OpenToF_logo_wordmark.png"
$wm.Dispose()

# ---------------------------------------------------------------------------------------------
# B) New mark: remove the uniform background (-> alpha), crop to the artwork.
# ---------------------------------------------------------------------------------------------
$raw = New-Object System.Drawing.Bitmap "$root\assets\branding\app_icon2.png"
$w = $raw.Width; $h = $raw.Height
$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$data = $raw.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($data.Stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$raw.UnlockBits($data)
$raw.Dispose()

$r = [MarkExtractor]::Extract($bytes, $w, $h)
"background rgb($($r[7]),$($r[8]),$($r[9]))  mark rgb($($r[4]),$($r[5]),$($r[6]))  bbox $($r[0]),$($r[1]) - $($r[2]),$($r[3])"

$full = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$data = $full.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
$full.UnlockBits($data)

$bw = $r[2] - $r[0] + 1; $bh = $r[3] - $r[1] + 1
$markRect = New-Object System.Drawing.Rectangle $r[0], $r[1], $bw, $bh
$mark = $full.Clone($markRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$full.Dispose()

# Draws the mark centered at (cx, cy) with the given height; -White paints it pure white (alpha kept).
function Draw-Mark($g, [double]$cx, [double]$cy, [double]$height, [switch]$White) {
  $width = $height * $mark.Width / $mark.Height
  $dest = New-Object System.Drawing.Rectangle ([int][math]::Round($cx - $width / 2)), ([int][math]::Round($cy - $height / 2)), ([int][math]::Round($width)), ([int][math]::Round($height))
  $attr = New-Object System.Drawing.Imaging.ImageAttributes
  $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
  if ($White) {
    $m = New-Object System.Drawing.Imaging.ColorMatrix
    $m.Matrix00 = 0; $m.Matrix11 = 0; $m.Matrix22 = 0; $m.Matrix33 = 1
    $m.Matrix40 = 1; $m.Matrix41 = 1; $m.Matrix42 = 1; $m.Matrix44 = 1
    $attr.SetColorMatrix($m)
  }
  $g.DrawImage($mark, $dest, 0, 0, $mark.Width, $mark.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr)
}

# 1) In-app mark (app bar): transparent, cropped tightly, 512 px tall.
$c = New-Canvas ([int][math]::Round(512 * $mark.Width / $mark.Height)) 512
Draw-Mark $c.Graphics ($c.Bitmap.Width / 2) 256 512
Save-Png $c "$root\assets\images\OpenToF_mark.png"

# 2) iOS / legacy Android icon: opaque white square (iOS rejects alpha), mark 68 % of the height.
$c = New-Canvas 1024 1024
$c.Graphics.Clear([System.Drawing.Color]::White)
Draw-Mark $c.Graphics 512 512 700
Save-Png $c "$root\assets\branding\app_icon.png"

# 3) Android adaptive foreground (transparent; the visible area is a ~66 % circle) + monochrome (themed icon).
$c = New-Canvas 1024 1024
Draw-Mark $c.Graphics 512 512 600
Save-Png $c "$root\assets\branding\app_icon_foreground.png"
$c = New-Canvas 1024 1024
Draw-Mark $c.Graphics 512 512 600 -White
Save-Png $c "$root\assets\branding\app_icon_monochrome.png"

# 4) Splash (Android < 12 / iOS): transparent, works on the white and the dark splash background.
$c = New-Canvas 1152 1152
Draw-Mark $c.Graphics 576 576 640
Save-Png $c "$root\assets\branding\splash_logo.png"

# 5) Android 12+ splash icon: the OS masks it with a circle of 2/3 of the canvas.
$c = New-Canvas 1152 1152
Draw-Mark $c.Graphics 576 576 560
Save-Png $c "$root\assets\branding\splash_android12.png"

# 6) Android status-bar (notification) icon: white glyph, 24 dp at each density (sizes 24/36/48/72/96 px).
foreach ($d in @(@('mdpi', 24), @('hdpi', 36), @('xhdpi', 48), @('xxhdpi', 72), @('xxxhdpi', 96))) {
  $size = $d[1]
  $c = New-Canvas $size $size
  Draw-Mark $c.Graphics ($size / 2) ($size / 2) ($size - 2) -White
  Save-Png $c "$root\android\app\src\main\res\drawable-$($d[0])\ic_stat_opentof.png"
}

$mark.Dispose()
"done"
