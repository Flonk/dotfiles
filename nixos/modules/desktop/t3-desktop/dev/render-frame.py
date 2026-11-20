import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BAND, BORDER, RADIUS, OUTER = 40.0, 4.0, 13.0, 17.0
MARK = 26
SIN17, COS17 = 0.29237170472273677, 0.9563047559630354


def load(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0
    a[..., :3] *= a[..., 3:]
    return a


def bilinear(tex, u, v, wrap):
    h, w = tex.shape[:2]
    x = u * w - 0.5
    y = v * h - 0.5
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]
    if wrap:
        ix = lambda i: i % w
        iy = lambda i: i % h
    else:
        ix = lambda i: np.clip(i, 0, w - 1)
        iy = lambda i: np.clip(i, 0, h - 1)
    a = tex[iy(y0), ix(x0)]
    b = tex[iy(y0), ix(x0 + 1)]
    c = tex[iy(y0 + 1), ix(x0)]
    d = tex[iy(y0 + 1), ix(x0 + 1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def straight(t):
    out = t.copy()
    alpha = t[..., 3:]
    np.divide(t[..., :3], alpha, out=out[..., :3], where=alpha > 0)
    return out


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def lift(srgb):
    c = to_linear(srgb)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    L = L + 0.2 * (1 - L)
    l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3
    m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3
    s = (L - 0.0894841775 * A - 1.2914855480 * B) ** 3
    return to_srgb(np.stack([
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s], axis=-1))


def overlay(b, s):
    return np.where(b < 0.5, 2 * b * s, 1 - 2 * (1 - b) * (1 - s))


def soft_light(b, s):
    d = np.where(b < 0.25, ((16 * b - 12) * b + 4) * b, np.sqrt(b))
    return np.where(s < 0.5, b - (1 - 2 * s) * b * (1 - b), b + (2 * s - 1) * (d - b))


def rotated_dots(px, py, inner, outer):
    cover = np.zeros_like(px)
    for i in range(4):
        for j in range(4):
            qx = px + (i + 0.5) / 4 - 0.5
            qy = py + (j + 0.5) / 4 - 0.5
            rx = COS17 * qx + SIN17 * qy
            ry = -SIN17 * qx + COS17 * qy
            r = np.hypot(np.mod(rx, 2.5) - 1.25, np.mod(ry, 2.5) - 1.25)
            if inner == outer:
                cover += r <= inner
            else:
                t = np.clip((r - inner) / (outer - inner), 0, 1)
                cover += 1 - t * t * (3 - 2 * t)
    return cover / 16


def rounded_box(px, py, lo, hi, radius):
    ext = (hi - lo) / 2
    cx = np.abs(px - (lo[0] + ext[0])) - (ext[0] - radius)
    cy = np.abs(py - (lo[1] + ext[1])) - (ext[1] - radius)
    return np.hypot(np.maximum(cx, 0), np.maximum(cy, 0)) + np.minimum(np.maximum(cx, cy), 0) - radius


def mark_knock(font_path):
    ss = 8
    img = Image.new("L", (MARK * ss, MARK * ss), 0)
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(font_path, round(MARK * 15 / 40) * ss)
    draw.text((MARK * ss / 2, MARK * ss / 2 + MARK * ss * 0.05), "T3", font=font, fill=255, anchor="mm")
    return np.asarray(img.resize((MARK, MARK), Image.LANCZOS)).astype(np.float64) / 255.0


def main(chrome_dir, width, height, font_path, out):
    W, H = int(width), int(height)
    palette = json.load(open(f"{chrome_dir}/palette.json"))
    hexrgb = lambda h: np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)])
    ground, accent = hexrgb(palette["ground"]), hexrgb(palette["accent"])

    py, px = np.mgrid[0:H, 0:W].astype(np.float64)
    px += 0.5
    py += 0.5

    lo = np.array([BORDER, BAND])
    hi = np.array([W - BORDER, H - BORDER])
    d = rounded_box(px, py, lo, hi, RADIUS)
    inner = np.clip(0.5 - d, 0, 1)[..., None]

    grain = straight(bilinear(load(f"{chrome_dir}/grain.png"), np.floor(px % 128) / 128 + 0.5 / 128, np.floor(py % 128) / 128 + 0.5 / 128, True))
    g = ground * (1 - grain[..., 3:]) + grain[..., :3] * grain[..., 3:]
    g = g + (1 - g) * (0.07 * rotated_dots(px, py, 0.4, 0.7))[..., None]
    fade = 1 - np.clip((py - BAND) / (144 * 0.7), 0, 1)
    g = g + (accent - g) * (0.55 * rotated_dots(px, py, 0.55, 0.55) * fade)[..., None]

    gradient = np.asarray(Image.open(f"{chrome_dir}/gradient.png").convert("RGBA")).astype(np.float64) / 255.0
    c = bilinear(gradient, (px - W / 2) / 3840 + 0.5, (py - H / 2) / 2160 + 0.5, False)[..., :3]
    lifted = lift(c)
    dots = straight(bilinear(load(f"{chrome_dir}/dots.png"), (px % 26) / 26, (py % 26) / 26, True))
    c = c + (overlay(c, dots[..., :3]) - c) * dots[..., 3:]
    noise = straight(bilinear(load(f"{chrome_dir}/noise.png"), (px % 128) / 128, (py % 128) / 128, True))
    c = c + (soft_light(c, noise[..., :3]) - c) * noise[..., 3:]

    ring = (np.clip(1.5 - d, 0, 1)[..., None] - inner)
    c = c + (lifted - c) * np.where(ring > 0, ring / np.maximum(1 - inner, 1e-4), 0)
    c = c * (1 - inner) + g * inner

    mx, my = round(W / 2 - MARK / 2), round((BAND - MARK) / 2)
    knock = mark_knock(font_path)
    sub = c[my:my + MARK, mx:mx + MARK]
    yy, xx = np.mgrid[0:MARK, 0:MARK] + 0.5
    rr = np.hypot(xx - MARK / 2, yy - MARK / 2)
    e0, e1 = MARK / 2 - 0.75, MARK / 2 + 0.25
    t = np.clip((rr - e0) / (e1 - e0), 0, 1)
    disc = 1 - t * t * (3 - 2 * t)
    c[my:my + MARK, mx:mx + MARK] = sub * (1 - (disc * (1 - knock))[..., None])

    sx = np.abs(px - W / 2) - (W / 2 - OUTER)
    sy = np.abs(py - H / 2) - (H / 2 - OUTER)
    outer = np.hypot(np.maximum(sx, 0), np.maximum(sy, 0)) + np.minimum(np.maximum(sx, sy), 0) - OUTER
    c = c * np.clip(0.5 - outer, 0, 1)[..., None]

    Image.fromarray(np.round(np.clip(c, 0, 1) * 255).astype(np.uint8), "RGB").save(out, optimize=True)


if __name__ == "__main__":
    main(*sys.argv[1:6])
