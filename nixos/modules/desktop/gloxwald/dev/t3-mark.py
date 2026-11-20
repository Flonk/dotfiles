import sys

from PIL import Image, ImageDraw, ImageFont

SIZE, SS = 160, 4


def main(accent_hex, font_path, out):
    accent = tuple(int(accent_hex.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    big = SIZE * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse((0, 0, big - 1, big - 1), fill=accent + (255,))
    font = ImageFont.truetype(font_path, round(big * 15 / 40))
    draw.text((big / 2, big * 21 / 40), "T3", font=font, fill=(0, 0, 0, 255), anchor="mm")
    img.resize((SIZE, SIZE), Image.LANCZOS).save(out, optimize=True)


if __name__ == "__main__":
    main(*sys.argv[1:4])
