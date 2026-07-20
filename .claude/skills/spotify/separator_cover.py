#!/usr/bin/env python3
import argparse
import colorsys
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

GOLDEN = 137.50776405003785
KNOWN_HUES = {2021: 94.00, 2022: 264.83, 2023: 45.76, 2024: 220.68}
SAT = 0.415
VAL = 0.559
INK = (18, 18, 18)
DIGIT_H_FRAC = 46 / 300
CENTER_Y_FRAC = 147.5 / 300
BUNDLED_FONT = Path(__file__).resolve().parent / "CircularSpotifyText-Bold.otf"
FONT_PATTERN = "Work Sans:bold"
FONT_PKG = "work-sans"
FONT_FILE = "WorkSans-Bold.*"


def hue_for_year(year):
    if year in KNOWN_HUES:
        return KNOWN_HUES[year]
    anchor = max(KNOWN_HUES)
    return (KNOWN_HUES[anchor] + GOLDEN * (year - anchor)) % 360


def bg_color(hue):
    r, g, b = colorsys.hsv_to_rgb((hue % 360) / 360, SAT, VAL)
    return tuple(round(c * 255) for c in (r, g, b))


def find_font():
    if BUNDLED_FONT.exists():
        return str(BUNDLED_FONT)
    if shutil.which("fc-match"):
        out = subprocess.run(
            ["fc-match", "-f", "%{file}", FONT_PATTERN],
            capture_output=True, text=True,
        ).stdout.strip()
        if "WorkSans" in out:
            return out
    hits = sorted(Path("/nix/store").glob(f"*-{FONT_PKG}-*/share/fonts/*/{FONT_FILE}"))
    if hits:
        return str(hits[-1])
    if shutil.which("nix-build"):
        root = subprocess.run(
            ["nix-build", "<nixpkgs>", "-A", FONT_PKG, "--no-out-link"],
            capture_output=True, text=True,
        ).stdout.strip()
        if root:
            hits = list(Path(root).rglob(FONT_FILE))
            if hits:
                return str(hits[0])
    sys.exit(f"could not locate {FONT_PATTERN}; pass --font")


def fit_font(path, text, target_h):
    lo, hi = 4, 4000
    while lo < hi:
        mid = (lo + hi + 1) // 2
        box = ImageFont.truetype(path, mid).getbbox(text)
        if box[3] - box[1] <= target_h:
            lo = mid
        else:
            hi = mid - 1
    return ImageFont.truetype(path, lo)


def render(text, hue, size, font_path):
    im = Image.new("RGB", (size, size), bg_color(hue))
    font = fit_font(font_path, text, round(DIGIT_H_FRAC * size))
    box = font.getbbox(text)
    ImageDraw.Draw(im).text(
        (size / 2 - (box[0] + box[2]) / 2,
         CENTER_Y_FRAC * size - (box[1] + box[3]) / 2),
        text, font=font, fill=INK,
    )
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("year", type=int)
    ap.add_argument("--hue", type=float)
    ap.add_argument("--text")
    ap.add_argument("--font")
    ap.add_argument("--size", type=int, default=640)
    ap.add_argument("--out")
    args = ap.parse_args()

    hue = args.hue if args.hue is not None else hue_for_year(args.year)
    text = args.text or str(args.year)
    out = args.out or f"{args.year}.png"
    rgb = bg_color(hue)

    render(text, hue, args.size, args.font or find_font()).save(out)
    print(f"{out}  {args.size}x{args.size}  hue={hue:.2f}  "
          f"hex=#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}")


if __name__ == "__main__":
    main()
