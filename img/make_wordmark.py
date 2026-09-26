"""Builds the coloured OpenToF wordmarks and the dark-theme logo from the branding sources in this folder.

    python img/make_wordmark.py          (needs Pillow: pip install pillow; and typst on PATH for the dark logo)

Sources:  OpenToF_Wordmark.png (black letters on transparent), opentof-logo.svg / opentof-logo.png (the logo).
Outputs (transparent background, cropped with a small margin):
    opentof-logo-dark.svg / .png     the logo for dark backgrounds: lighter blue (white bed and red marking kept)
    OpenToF_Wordmark_color.png       "OPEN" dark blue, "TOF" logo blue
    OpenToF_Wordmark_logo.png        same, with the second O replaced by the logo ("OPENT<logo>F"); the lower
                                     edge of the logo's trampoline bed sits on the letters' baseline
    OpenToF_Wordmark_color_dark.png  dark-theme versions of the two wordmarks: "OPEN" near-white, "TOF" light blue
    OpenToF_Wordmark_logo_dark.png
"""
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).parent
LOGO_SCALE = 2.0  # logo height / letter (cap) height
MARGIN = 24  # px around the result
NOISE = 16  # alpha below this is scanning noise around the letters, dropped

# Light theme (on white): the logo's own colours.
LOGO_BLUE = "#0153E3"  # stroke/fill colour of opentof-logo.svg
DARK_BLUE = "#0B2A6F"  # same hue as LOGO_BLUE, much darker
# Dark theme (on ~#121318): contrast >= 6:1 instead of 3.0 (blue) / 1.4 (dark blue).
DARK_THEME_BLUE = "#5B9BFF"
DARK_THEME_OPEN = "#E8EEFA"


def rgb(hex_colour: str) -> tuple[int, int, int]:
    h = hex_colour.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def letter_spans(alpha: Image.Image) -> list[tuple[int, int]]:
    """Column ranges [start, end) of the letters (separated by fully empty columns)."""
    w, h = alpha.size
    px = alpha.load()
    ink = [any(px[x, y] > 0 for y in range(h)) for x in range(w)]
    spans, start = [], None
    for x, on in enumerate(ink + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            spans.append((start, x))
            start = None
    return spans


def bed_bottom(logo: Image.Image) -> int:
    """Lowest row of the logo's opaque white trampoline bed."""
    px = logo.load()
    for y in range(logo.height - 1, -1, -1):
        for x in range(logo.width):
            r, g, b, a = px[x, y]
            if a > 250 and min(r, g, b) > 245:
                return y
    raise ValueError("no white trampoline bed found in the logo")


def coloured(alpha: Image.Image, colour: str) -> Image.Image:
    layer = Image.new("RGBA", alpha.size, rgb(colour) + (0,))
    layer.putalpha(alpha)
    return layer


def make_dark_logo(width_px: int) -> Image.Image:
    """Recolours opentof-logo.svg's blue for dark backgrounds and renders it (via typst) at width_px."""
    svg = (HERE / "opentof-logo.svg").read_text(encoding="utf-8")
    svg = re.sub(r"<metadata.*?</metadata>\s*", "", svg, flags=re.S)  # provenance of the original only
    svg = re.sub(LOGO_BLUE, DARK_THEME_BLUE, svg, flags=re.I)
    # The white trampoline bed and its red marking stay as they are (the bed reads as a white sheet).
    (HERE / "opentof-logo-dark.svg").write_text(svg, encoding="utf-8")

    typst = shutil.which("typst")
    if typst is None:
        raise SystemExit("typst not found on PATH (needed to render opentof-logo-dark.svg)")
    with tempfile.TemporaryDirectory() as tmp:
        (Path(tmp) / "logo.svg").write_text(svg, encoding="utf-8")
        (Path(tmp) / "render.typ").write_text(
            '#set page(width: auto, height: auto, margin: 0pt, fill: none)\n'
            '#image("logo.svg", width: 4000pt)\n',
            encoding="utf-8",
        )
        subprocess.run([typst, "compile", "--ppi", "72", "render.typ", "render.png"], cwd=tmp, check=True)
        big = Image.open(Path(tmp) / "render.png").convert("RGBA")
    big = big.crop(big.getbbox())
    logo = big.resize((width_px, round(big.height * width_px / big.width)), Image.LANCZOS)
    logo.save(HERE / "opentof-logo-dark.png")
    return logo


def build(alpha, spans, logo, bed, open_colour, tof_colour, suffix) -> None:
    height = alpha.height
    gap = spans[1][0] - spans[0][1]  # spacing between letters

    def letter(i: int) -> Image.Image:
        colour = open_colour if i < 4 else tof_colour
        return coloured(alpha.crop((spans[i][0], 0, spans[i][1], height)), colour)

    # 1) Coloured wordmark, letters unchanged.
    out = Image.new("RGBA", (alpha.width + 2 * MARGIN, height + 2 * MARGIN), (0, 0, 0, 0))
    for i, (x0, _) in enumerate(spans):
        out.alpha_composite(letter(i), (MARGIN + x0, MARGIN))
    out.save(HERE / f"OpenToF_Wordmark_color{suffix}.png")

    # 2) Second O replaced by the logo, its trampoline bed on the baseline.
    lh = round(height * LOGO_SCALE)
    lw = round(logo.width * lh / logo.height)
    logo = logo.resize((lw, lh), Image.LANCZOS)
    overhang = round(bed * lh) - height  # logo rows above the letters' top
    below = lh - overhang - height  # logo rows below the baseline

    parts: list[tuple[Image.Image, int]] = []  # (image, y offset relative to the letters' top)
    for i in range(7):
        parts.append((logo, -overhang) if i == 5 else (letter(i), 0))
    width = sum(p.width for p, _ in parts) + gap * 6
    out = Image.new("RGBA", (width + 2 * MARGIN, overhang + height + below + 2 * MARGIN), (0, 0, 0, 0))
    x = MARGIN
    for img, dy in parts:
        out.alpha_composite(img, (x, MARGIN + overhang + dy))
        x += img.width + gap
    out.save(HERE / f"OpenToF_Wordmark_logo{suffix}.png")


def main() -> None:
    word = Image.open(HERE / "OpenToF_Wordmark.png").convert("RGBA")
    alpha = word.getchannel("A").point(lambda a: 0 if a < NOISE else a)
    alpha = alpha.crop(alpha.getbbox())
    spans = letter_spans(alpha)
    assert len(spans) == 7, f"expected the 7 letters O P E N T O F, found {len(spans)}"

    logo = Image.open(HERE / "opentof-logo.png").convert("RGBA")
    logo = logo.crop(logo.getbbox())
    bed = bed_bottom(logo) / logo.height  # bed edge as a fraction of the logo height (same shape in both themes)
    dark_logo = make_dark_logo(logo.width)

    build(alpha, spans, logo, bed, DARK_BLUE, LOGO_BLUE, "")
    build(alpha, spans, dark_logo, bed, DARK_THEME_OPEN, DARK_THEME_BLUE, "_dark")
    print("wrote opentof-logo-dark.svg/.png, OpenToF_Wordmark_color[_dark].png, OpenToF_Wordmark_logo[_dark].png")


if __name__ == "__main__":
    main()
