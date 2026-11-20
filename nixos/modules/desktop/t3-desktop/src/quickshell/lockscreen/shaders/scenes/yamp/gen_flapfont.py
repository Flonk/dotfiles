#!/usr/bin/env python3
# Bakes the split-flap font into flap_font.png: an 8x9 atlas of signed
# distance fields of CHARS (cell CW x CH, height = 1 tile unit, distances
# clamped to +-RANGE/2 and mapped to [0, 255], inside < 0.5), caps centred
# on the cell, CAP of the cell tall, in Montserrat SemiBold.
#
# Run: just gen-flapfont, or by hand:
#      nix-shell -p "python3.withPackages(p: [p.pillow p.numpy p.scipy])" \
#        --run "python3 gen_flapfont.py <Montserrat-SemiBold.ttf>"

import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt

CHARS = "0123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\u2019."
CW, CH, COLS, ROWS = 96, 128, 8, 9
UP = 4
RANGE = 0.25
CAP = 0.5

probe = ImageFont.truetype(sys.argv[1], 1000)
_, top, _, bot = probe.getbbox("H", anchor="ls")
font = ImageFont.truetype(sys.argv[1], int(round(1000 * CAP * CH * UP / (bot - top))))


def render(ch):
    w, h = CW * UP, CH * UP
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).text((w / 2, h / 2 + CAP * CH * UP / 2), ch, font=font, fill=255, anchor="ms")
    return np.array(img) > 127


atlas = np.full((ROWS * CH, COLS * CW), 255, np.uint8)
for i, ch in enumerate(CHARS):
    m = render(ch)
    d = distance_transform_edt(~m) - distance_transform_edt(m)
    d = d.reshape(CH, UP, CW, UP).mean(axis=(1, 3)) / (CH * UP)
    v = np.round((np.clip(d, -RANGE / 2, RANGE / 2) / RANGE + 0.5) * 255).astype(np.uint8)
    r, c = divmod(i, COLS)
    atlas[r * CH:(r + 1) * CH, c * CW:(c + 1) * CW] = v

Image.fromarray(atlas).convert("RGB").save("../../assets/flap_font.png", optimize=True)
