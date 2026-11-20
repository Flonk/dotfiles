import json
import sys

import numpy as np
from PIL import Image

REF_W, REF_H = 1920, 1200
IMG_W, IMG_H = 3840, 2160
SCALE = 0.5
TURN = np.radians(110.0)


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def srgb_to_oklab(rgb):
    r, g, b = to_linear(np.asarray(rgb, dtype=float))
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return np.array([
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ])


def oklab_to_srgb(lab):
    L, a, b = lab
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return to_srgb(np.array([
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ]))


def shift(rgb, dl, dc, dh):
    L, a, b = srgb_to_oklab(rgb)
    c = max(np.hypot(a, b) + dc, 0.0)
    h = np.arctan2(b, a) + np.radians(dh)
    return oklab_to_srgb(np.array([L + dl, c * np.cos(h), c * np.sin(h)]))


def main(accent_hex, out, palette_out):
    accent = np.array([int(accent_hex.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)])
    stop1 = accent
    stop2 = shift(accent, 0.087, -0.009, 24.0)
    glow = shift(accent, 0.16, -0.031, 24.0 * 1.8)

    w, h = int(IMG_W * SCALE), int(IMG_H * SCALE)
    xs = (np.arange(w) + 0.5) / SCALE - IMG_W / 2
    ys = (np.arange(h) + 0.5) / SCALE - IMG_H / 2
    qx, qy = np.meshgrid(xs, ys)

    dx, dy = np.sin(TURN), -np.cos(TURN)
    length = abs(REF_W * dx) + abs(REF_H * dy)
    t = np.clip((qx * dx + qy * dy) / length + 0.5, 0.0, 1.0)[..., None]
    base = np.where(t < 0.5, stop1 + (stop2 - stop1) * (t * 2), stop2 + (stop1 - stop2) * (t * 2 - 1))

    ox = (0.5 + np.cos(TURN) * 0.4) * REF_W - REF_W / 2
    oy = (0.2 + np.sin(TURN) * 0.3) * REF_H - REF_H / 2
    vmax = max(REF_W, REF_H)
    d = np.hypot((qx - ox) / (0.42 * vmax), (qy - oy) / (0.28 * vmax))
    alpha = np.clip(1.0 - d / 0.7, 0.0, 1.0)[..., None]
    color = base + (glow - base) * alpha

    Image.fromarray(np.round(np.clip(color, 0, 1) * 255).astype(np.uint8), "RGB").save(out, optimize=True)
    to_hex = lambda c: "#" + "".join(f"{round(float(v) * 255):02x}" for v in np.clip(c, 0, 1))
    with open(palette_out, "w") as f:
        json.dump({"accent": to_hex(stop1), "accent2": to_hex(stop2), "glow": to_hex(glow)}, f)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
