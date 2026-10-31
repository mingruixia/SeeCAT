"""Render the SeeCAT mark (seecat.gui.icon('logo')) to PNG files for the
window icon, which MATLAB R2020b wants as PNG/JPEG/GIF.

    python tools/make_logo.py      # writes SeeCAT/resources/logo_<n>.png
"""
from pathlib import Path
from PIL import Image, ImageDraw

ACCENT = (0x3B, 0x5B, 0xDB, 255)
WHITE = (255, 255, 255, 255)
OUT = Path(__file__).resolve().parents[1] / "SeeCAT" / "resources"


def draw(size):
    s = 16                                   # supersampling
    k = size * s / 32                        # the mark is drawn on a 32 x 32 grid
    im = Image.new("RGBA", (size * s, size * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, size * s - 1, size * s - 1], radius=7 * k, fill=ACCENT)
    pts = [(7, 24.5), (7, 10.5), (12, 14.5), (20, 14.5), (25, 10.5), (25, 24.5)]
    pts = [(x * k, y * k) for x, y in pts]
    w = round(2.2 * k)
    d.line(pts, fill=WHITE, width=w, joint="curve")
    for x, y in (pts[0], pts[-1]):           # round caps
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=WHITE)
    d.line([(12.5 * k, 19.5 * k), (19.5 * k, 19.5 * k)], fill=WHITE, width=round(1.3 * k))
    for cx in (12.5, 19.5):
        d.ellipse([(cx - 2) * k, 17.5 * k, (cx + 2) * k, 21.5 * k], fill=WHITE)
    return im.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for n in (16, 32, 64, 256):
        draw(n).save(OUT / f"logo_{n}.png")
