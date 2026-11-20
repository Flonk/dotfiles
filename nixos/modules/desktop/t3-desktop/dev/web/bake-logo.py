import subprocess
import sys

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt

W, H = 2048, 1024
SS = 4
PAD = 0.08
RANGE = 24.0


def main(svg, out):
    vw, vh = 185.52, 87.77
    scale = min(W * (1 - 2 * PAD) / vw, H * (1 - 2 * PAD) / vh) * SS
    big_w, big_h = W * SS, H * SS
    raw = subprocess.run(
        ["rsvg-convert", "-z", str(scale), "-f", "png", svg],
        check=True, capture_output=True).stdout
    tmp = out + ".raw.png"
    open(tmp, "wb").write(raw)
    logo = Image.open(tmp).convert("RGBA")
    canvas = Image.new("L", (big_w, big_h), 0)
    canvas.paste(logo.getchannel("A"), ((big_w - logo.width) // 2, (big_h - logo.height) // 2))
    mask = np.asarray(canvas) > 127
    dist = distance_transform_edt(~mask) - distance_transform_edt(mask)
    dist = dist.reshape(H, SS, W, SS).mean(axis=(1, 3)) / SS
    enc = np.clip(dist / RANGE * 0.5 + 0.5, 0, 1)
    Image.fromarray(np.round(enc * 255).astype(np.uint8), "L").save(out, optimize=True)
    print(f"logo {logo.width / SS:.1f}x{logo.height / SS:.1f}px in {W}x{H}, range +-{RANGE}px")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
