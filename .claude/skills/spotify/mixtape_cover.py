#!/usr/bin/env python3
import argparse
import re

from PIL import Image, ImageDraw, ImageFont

from separator_cover import bg_color, find_font, hue_for_year

BODY = (18, 18, 18)
TEXT = (108, 108, 108)
STRIP_H_FRAC = 40 / 640
MARGIN_X_FRAC = 30 / 640
BASELINE_FRAC = 608 / 640
CAP_H_FRAC = 40.5 / 640
PITCH_PER_CAP = 71 / 40.5


def cap_height(font):
    box = font.getbbox("H")
    return box[3] - box[1]


def fit_font(path, target_cap):
    lo, hi = 4, 4000
    while lo < hi:
        mid = (lo + hi + 1) // 2
        if cap_height(ImageFont.truetype(path, mid)) <= target_cap:
            lo = mid
        else:
            hi = mid - 1
    return ImageFont.truetype(path, lo)


def shrink_to_fit(path, lines, target_cap, max_width):
    font = fit_font(path, target_cap)
    while font.size > 4:
        if max(font.getlength(l) for l in lines) <= max_width:
            return font
        font = ImageFont.truetype(path, font.size - 1)
    return font


def render(artists, hue, size, font_path):
    im = Image.new("RGB", (size, size), BODY)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, size, round(STRIP_H_FRAC * size) - 1], fill=bg_color(hue))

    lines = [f"{a.rstrip('.')}." for a in artists]
    margin = round(MARGIN_X_FRAC * size)
    font = shrink_to_fit(font_path, lines, CAP_H_FRAC * size, size - 2 * margin)

    baseline = BASELINE_FRAC * size
    pitch = cap_height(font) * PITCH_PER_CAP
    for i, line in enumerate(lines):
        y = baseline - (len(lines) - 1 - i) * pitch
        d.text((margin, y), line, font=font, fill=TEXT, anchor="ls")
    return im, font.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("month", help="yyyy-MM")
    ap.add_argument("--artists", nargs="+", required=True)
    ap.add_argument("--hue", type=float)
    ap.add_argument("--font")
    ap.add_argument("--size", type=int, default=640)
    ap.add_argument("--out")
    args = ap.parse_args()

    if not re.fullmatch(r"\d{4}-\d{2}", args.month):
        raise SystemExit("month must look like 2025-03")
    year = int(args.month[:4])
    hue = args.hue if args.hue is not None else hue_for_year(year)
    out = args.out or f"{args.month}-mixtape.png"

    im, px = render(args.artists, hue, args.size, args.font or find_font())
    im.save(out)
    rgb = bg_color(hue)
    print(f"{out}  {args.size}x{args.size}  hue={hue:.2f}  "
          f"hex=#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}  font={px}px  "
          f"lines={len(args.artists)}")


if __name__ == "__main__":
    main()
