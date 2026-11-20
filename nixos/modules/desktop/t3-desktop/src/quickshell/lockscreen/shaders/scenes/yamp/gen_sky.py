#!/usr/bin/env python3
# Bakes the night sky into sky.png (RGB8, SKY_W wide, alpha unused so nothing
# gets premultiplied) for the stars mode. Data: d3-celestial's stars.6.json,
# constellations.lines.json and constellations.json (Hipparcos positions,
# J2000). A unit vector is packed into two texels as three 16-bit numbers.
#   rows 0..31   star records, 3 texels each: vector, (mag, b-v, 0); sorted by
#                sky cell, a star is listed in every cell its disk (MARGIN)
#                touches, so the shader only ever reads its own cell
#   rows 32..35  cell table, CELLS_RA x CELLS_DEC cells (RA fastest): first
#                record (16 bit), count
#   rows 36..41  tour targets, 32 texels each: (first segment 16 bit,
#                segment count), (name length, type, deep-sky kind or planet),
#                label vector, then one texel per name character (flap font
#                index, 255 blank; advance); deep-sky objects also (axes * 40,
#                position angle) at 29 and their colour at 30. Types: 0
#                constellation, 1 asterism, 2 deep-sky object, 3 named star,
#                4 planet, 5 star-hopping guide, 6 Moon, 7 ISS (the last
#                three placed by the shader)
#   rows 42..55  figure segments, 6 texels: two vectors, then (mag, b-v) of
#                the star at each end
#   rows 56..119 the satellite emoji (Noto Color Emoji), 64 x 64: colour
#                premultiplied at x 0..63, coverage at x 64..127; the shark
#                emoji for the fish scene the same way at x 128..255
#
# Run: just gen-sky (fetches data and font), or by hand:
#      nix-shell -p "python3.withPackages(p: [p.pillow p.numpy])" \
#        --run "python3 gen_sky.py <data dir> <Montserrat-SemiBold.ttf> <NotoColorEmoji.ttf>"

import json
import unicodedata
import math
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

DATA, FONT, EMOJI = sys.argv[1], sys.argv[2], sys.argv[3]
SKY_W, SKY_H = 1024, 56 + 64
CELLS_RA, CELLS_DEC = 48, 24
MAG = 5.0
DEC_MIN = -55.
MARGIN = math.radians(1.3)
CONST = [
    ("Ori", "ORION"), ("UMa", "URSA MAJOR"), ("UMi", "URSA MINOR"), ("Cas", "CASSIOPEIA"),
    ("Cyg", "CYGNUS"), ("Lyr", "LYRA"), ("Sgr", "SAGITTARIUS"), ("Sco", "SCORPIUS"),
    ("Leo", "LEO"), ("Tau", "TAURUS"), ("Gem", "GEMINI"), ("Boo", "BOOTES"),
    ("Aql", "AQUILA"), ("Peg", "PEGASUS"), ("And", "ANDROMEDA"), ("Per", "PERSEUS"),
    ("Aur", "AURIGA"), ("CMa", "CANIS MAJOR"), ("Vir", "VIRGO"), ("CrB", "CORONA BOREALIS"),
    ("Dra", "DRACO"), ("Her", "HERCULES"), ("Cap", "CAPRICORNUS"), ("Aqr", "AQUARIUS"),
    ("Ari", "ARIES"), ("Cnc", "CANCER"), ("Lib", "LIBRA"), ("Cep", "CEPHEUS"),
    ("Oph", "OPHIUCHUS"), ("Psc", "PISCES"), ("CMi", "CANIS MINOR"), ("Lep", "LEPUS"),
    ("Del", "DELPHINUS"), ("Sge", "SAGITTA"), ("Crv", "CORVUS"), ("Tri", "TRIANGULUM"),
    ("Lyn", "LYNX"), ("Cam", "CAMELOPARDALIS"), ("Ser", "SERPENS"), ("Hya", "HYDRA"),
    ("Com", "COMA BERENICES"), ("Eri", "ERIDANUS"),
]
ASTERISMS = [
    ("BIG DIPPER", [[54061, 53910, 58001, 59774, 54061], [59774, 62956, 65378, 67301]]),
    ("SUMMER TRIANGLE", [[91262, 102098, 97649, 91262]]),
    ("WINTER HEXAGON", [[32349, 37279, 37826, 24608, 21421, 24436, 32349]]),
    ("GREAT SQUARE", [[113963, 113881, 677, 1067, 113963]]),
    ("ORIONS BELT", [[26727, 26311, 25930]]),
    ("TEAPOT", [[88635, 89931, 90185, 88635], [89931, 92041, 93506, 90185], [89931, 90496, 92041],
                [92041, 92855, 93864, 93506]]),
    ("SICKLE", [[49669, 49583, 50583, 50335, 48455, 47908]]),
    ("SPRING TRIANGLE", [[69673, 65474, 49669, 69673]]),
    ("NORTHERN CROSS", [[102098, 100453, 95947], [102488, 100453, 97165]]),
    ("THE KIDS", [[23453, 23767, 23416, 23453]]),
    ("LITTLE DIPPER", [[11767, 85822, 82080, 77055, 79822, 75097, 72607, 77055]]),
    ("ARC TO ARCTURUS", [[62956, 65378, 67301, 69673, 65474]]),
]
GUIDES = [
    ("FIND POLARIS", [[53910, 54061, 11767]]),
    ("FIND SIRIUS", [[25930, 26727, 32349]]),
    ("FIND ALDEBARAN", [[26727, 25930, 21421]]),
]
# name, RA, Dec (deg), kind (0 galaxy, 1 cluster, 2 nebula, 3 ring), display
# axes (deg), position angle (deg, north through east), colour
DSO = [
    ("M31 ANDROMEDA GALAXY", 10.68, 41.27, 0, 3.2, 1.0, 35, (0.95, 0.88, 0.78)),
    ("M33 TRIANGULUM GALAXY", 23.46, 30.66, 0, 1.1, 0.7, 23, (0.85, 0.88, 0.95)),
    ("M51 WHIRLPOOL GALAXY", 202.47, 47.2, 0, 0.45, 0.35, 0, (0.88, 0.9, 0.95)),
    ("M81 BODES GALAXY", 148.89, 69.07, 0, 0.55, 0.28, 157, (0.95, 0.9, 0.8)),
    ("M45 PLEIADES", 56.75, 24.12, 1, 1.8, 1.8, 0, (0.7, 0.82, 1.0)),
    ("M44 BEEHIVE CLUSTER", 130.1, 19.67, 1, 1.5, 1.5, 0, (0.95, 0.92, 0.85)),
    ("M13 HERCULES CLUSTER", 250.42, 36.46, 1, 0.45, 0.45, 0, (1.0, 0.95, 0.85)),
    ("M42 ORION NEBULA", 83.82, -5.39, 2, 1.1, 0.9, 0, (0.95, 0.55, 0.75)),
    ("M8 LAGOON NEBULA", 270.92, -24.38, 2, 1.3, 0.6, 90, (0.95, 0.5, 0.6)),
    ("M57 RING NEBULA", 283.4, 33.03, 3, 0.35, 0.3, 60, (0.45, 0.95, 0.8)),
]
STARS = [
    ("POLARIS", 11767), ("VEGA", 91262), ("BETELGEUSE", 27989), ("SIRIUS", 32349),
    ("ARCTURUS", 69673), ("CAPELLA", 24608), ("RIGEL", 24436), ("ALDEBARAN", 21421),
    ("ANTARES", 80763), ("SPICA", 65474), ("DENEB", 102098), ("ALTAIR", 97649),
    ("REGULUS", 49669), ("POLLUX", 37826), ("PROCYON", 37279), ("FOMALHAUT", 113368),
    ("ALGOL", 14576), ("MIZAR AND ALCOR", 65378),
]
PLANETS = ["VENUS", "MARS", "JUPITER", "SATURN"]

img = np.zeros((SKY_H, SKY_W, 3), np.uint8)


def put(i, rgb):
    img[i // SKY_W, i % SKY_W] = rgb


def vec(ra, dec):
    a, d = math.radians(ra), math.radians(dec)
    return (math.cos(d) * math.cos(a), math.cos(d) * math.sin(a), math.sin(d))


def u16(v):
    return int(round((v * 0.5 + 0.5) * 65535))


def put_vec(i, v):
    x, y, z = (u16(c) for c in v)
    put(i, (x >> 8, x & 255, y >> 8))
    put(i + 1, (y & 255, z >> 8, z & 255))


def cell(ra_bin, dec_bin):
    return dec_bin * CELLS_RA + ra_bin


stars = []
for f in json.load(open(f"{DATA}/stars.6.json"))["features"]:
    mag = f["properties"]["mag"]
    ra, dec = f["geometry"]["coordinates"]
    if mag > MAG or dec < DEC_MIN:
        continue
    bv = f["properties"].get("bv") or "0.6"
    stars.append((ra, dec, mag, float(bv)))

cells = [[] for _ in range(CELLS_RA * CELLS_DEC)]
for k, (ra, dec, mag, bv) in enumerate(stars):
    d = math.radians(dec)
    a = math.radians(ra) % (2 * math.pi)
    d0, d1 = d - MARGIN, d + MARGIN
    b0 = max(0, int((math.degrees(d0) + 90) / 180 * CELLS_DEC))
    b1 = min(CELLS_DEC - 1, int((math.degrees(d1) + 90) / 180 * CELLS_DEC))
    c = math.cos(min(abs(d) + MARGIN, math.radians(89.9)))
    span = MARGIN / c
    for db in range(b0, b1 + 1):
        if span >= math.pi:
            ras = range(CELLS_RA)
        else:
            r0 = math.floor((a - span) / (2 * math.pi) * CELLS_RA)
            r1 = math.floor((a + span) / (2 * math.pi) * CELLS_RA)
            ras = sorted({r % CELLS_RA for r in range(r0, r1 + 1)})
        for rb in ras:
            cells[cell(rb, db)].append(k)

rec = 0
for ci, ks in enumerate(cells):
    put(32 * SKY_W + ci, (rec >> 8, rec & 255, len(ks)))
    for k in ks:
        ra, dec, mag, bv = stars[k]
        put_vec(3 * rec, vec(ra, dec))
        put(3 * rec + 2, (int(round(np.clip((mag + 2) / 8, 0, 1) * 255)), int(round(np.clip((bv + 0.4) / 2.4, 0, 1) * 255)), 0))
        rec += 1
assert 3 * rec <= 32 * SKY_W, rec
assert max(len(k) for k in cells) < 256

probe = ImageFont.truetype(FONT, 1000)
_, top, _, bot = probe.getbbox("H", anchor="ls")
scale = 0.5 / (bot - top)
lines = {f["id"]: f["geometry"]["coordinates"] for f in json.load(open(f"{DATA}/constellations.lines.json"))["features"]}
labels = {f["id"]: f["properties"]["display"] for f in json.load(open(f"{DATA}/constellations.json"))["features"]}
allstars = json.load(open(f"{DATA}/stars.6.json"))["features"]
hip = {f["id"]: f["geometry"]["coordinates"] for f in allstars}
catv = np.array([vec(*f["geometry"]["coordinates"]) for f in allstars])
catm = [(f["properties"]["mag"], float(f["properties"].get("bv") or "0.6")) for f in allstars]


def star_at(p):
    return catm[int(np.argmax(catv @ np.array(vec(*p))))]


def mag_bv(m, bv):
    return int(round(np.clip((m + 2) / 8, 0, 1) * 255)), int(round(np.clip((bv + 0.4) / 2.4, 0, 1) * 255))

targets = []
names = {f["id"]: f["properties"]["name"] for f in json.load(open(f"{DATA}/constellations.json"))["features"]}
for cid in sorted(names):
    if cid in lines and cid not in {c for c, _ in CONST}:
        plain = unicodedata.normalize("NFKD", names[cid]).encode("ascii", "ignore").decode().upper()
        CONST.append((cid, "".join(c for c in plain if c.isalpha() or c == " ")))
for cid, name in CONST:
    targets.append(dict(type=0, name=name, lines=lines[cid], at=labels[cid][:2]))
def figure(kind, name, chains):
    lines = [[hip[h] for h in c] for c in chains]
    uniq = {h: hip[h] for c in chains for h in c}
    v = np.sum([vec(*p) for p in uniq.values()], axis=0)
    at = [math.degrees(math.atan2(v[1], v[0])), math.degrees(math.asin(v[2] / np.linalg.norm(v)))]
    targets.append(dict(type=kind, name=name, lines=lines, at=at))


for name, chains in ASTERISMS:
    figure(1, name, chains)
for name, chains in GUIDES:
    figure(5, name, chains)
for name, ra, dec, kind, sa, sb, pa, col in DSO:
    targets.append(dict(type=2, name=name, lines=[], at=[ra if ra <= 180 else ra - 360, dec], kind=kind, shape=(sa, sb, pa), col=col))
for name, h in STARS:
    targets.append(dict(type=3, name=name, lines=[], at=hip[h]))
for i, name in enumerate(PLANETS):
    targets.append(dict(type=4, name=name, lines=[], at=[0., 0.], param=i))
targets.append(dict(type=6, name="MOON", lines=[], at=[0., 0.]))
targets.append(dict(type=7, name="ISS", lines=[], at=[0., 0.]))
print("planets from", next(i for i, t in enumerate(targets) if t["type"] == 4))
assert len(targets) <= 192
print("deep-sky objects from", next(i for i, t in enumerate(targets) if t["type"] == 2), "of", len(targets))

seg = 0
for ti, t in enumerate(targets):
    base = 36 * SKY_W + 32 * ti
    first = seg
    for line in t["lines"]:
        for p, q in zip(line, line[1:]):
            o = 42 * SKY_W + 6 * seg
            put_vec(o, vec(*p))
            put_vec(o + 2, vec(*q))
            put(o + 4, (*mag_bv(*star_at(p)), 0))
            put(o + 5, (*mag_bv(*star_at(q)), 0))
            seg += 1
    put(base, (first >> 8, first & 255, seg - first))
    put(base + 1, (len(t["name"]), t["type"], t.get("kind", t.get("param", 0))))
    put_vec(base + 2, vec(*t["at"]))
    for j, ch in enumerate(t["name"]):
        if ch == " ":
            code = 255
        elif ch.isdigit():
            code = int(ch)
        else:
            code = 11 + ord(ch) - ord("A")
        put(base + 4 + j, (code, int(round(probe.getlength(ch) * scale * 255)), 0))
    if t["type"] == 2:
        sa, sb, pa = t["shape"]
        put(base + 29, (int(round(sa * 40)), int(round(sb * 40)), int(round(pa / 180 * 255))))
        put(base + 30, tuple(int(round(c * 255)) for c in t["col"]))
assert 6 * seg <= 14 * SKY_W, seg
assert 4 + max(len(t["name"]) for t in targets) <= 29

emoji = ImageFont.truetype(EMOJI, 109)
for x0, ch in ((0, "\U0001F6F0"), (128, "\U0001F988")):
    canvas = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(canvas).text((80, 80), ch, font=emoji, embedded_color=True, anchor="mm")
    canvas = canvas.crop(canvas.getbbox())
    side = max(canvas.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(canvas, ((side - canvas.width) // 2, (side - canvas.height) // 2))
    e = np.array(square.resize((64, 64), Image.LANCZOS)).astype(float) / 255
    img[56:120, x0:x0 + 64] = np.round(e[..., :3] * e[..., 3:] * 255).astype(np.uint8)
    img[56:120, x0 + 64:x0 + 128] = np.round(np.repeat(e[..., 3:], 3, axis=2) * 255).astype(np.uint8)

Image.fromarray(img).save("../../assets/sky.png", optimize=True)
print(f"{len(stars)} stars, {rec} records, {len(targets)} targets, {seg} segments")
