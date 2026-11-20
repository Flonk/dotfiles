# Bake real road networks from OpenStreetMap into ../../assets/maps.png for
# the traffic scene's map sub-modes (96_map.glsl).
#
# For each map in MAPS: fetch the drivable ways round the centre (Overpass,
# cached in the data dir), project them to screen units (R metres = half the
# screen height), split them at junctions into directed lanes (one per
# direction, offset to the driving side, trimmed back from the junction),
# join every allowed turn with a curved connector, find roundabouts (tagged,
# or small cycles of one-way roads; driven at the map's ring_speed, m/s, if
# it has one), and work out which connectors cross or
# merge and who gives way: ring traffic over traffic entering, then the
# higher road class, then straight on over turning, then traffic from the
# right.
#
# The texture is 1024 wide, RGB, read as a flat array of 24-bit words
# (texel i = (i % 1024, i / 1024), r << 16 | g << 8 | b). Fixed-point
# values: f = (v + FX_OFF) / FX_RANGE * 2^24.
#   word 0           map count, then per map its base word
#   map header (at base, offsets relative to base):
#     0 lane count (lanes first, connectors after), 1 edge count,
#     2 edge table, 3 points, 4 successor lists, 5 give-way lists,
#     6 entry lanes, 7 entry count, 8 segments, 9 segment count,
#     10 grid cells, 11 cell lists, 12 grid nx, 13 grid ny,
#     14 grid min x (fx), 15 grid min y (fx), 16 cell size (fx),
#     17 car length (fx), 18 km per unit (fx; past 3.9 km as minus tens
#     of km), 19 name start, 20 name
#     length, 21 drive left (bit 0) and cars coming in anywhere on the map
#     rather than at the edge of the screen (bit 1, the map's scatter, for one
#     whose roads all lie on the screen), a treeline and snowline after its terrain
#     (bit 2), 23 building count, 24 buildings, 25 their
#     corners, 26 building grid cells, 27 their lists, 22 car count (the map's
#     max_cars, the most it carries without jamming, else one per CAR_EVERY
#     metres of lane; at most MAX_CARS); entry lanes are those starting off
#     the screen
#   edge (14 words): first point (index into the points), point count,
#     length (fx), successors start, count, give-way start, count (edges
#     whose cars this one gives way to), flags (bit 0 connector, bit 1
#     ring, bits 2-4 layer + 2, bits 8-15 speed in units/s * 1000, bits
#     16-19 lanes, 20-23 lanes at the far end: a lane edge is a whole
#     carriageway, its centre line between its lanes, OSM lanes tags),
#     the carriageway's width at the start and at the far end (fx; OSM
#     width, shared out by lanes on two-way roads, else lanes * LANE_W),
#     and for a connector how far right of the centre line of the lane
#     before it it starts and of the lane after it it ends (fx; a car
#     moving on shifts by them so it stays where it is), and its traffic
#     light + 1 (0 none; bits 0-15 the junction's lights, 16 the phase;
#     bit 20 set on a piece that just carries on the lane before it), and
#     for a connector the lane it comes out of + 1 (0 for a lane)
#   spawn list (header 41 count, 42 start): lanes to start cars on, each
#     as often as its length * lanes * flow; entry lanes are listed as
#     often as their flow * lanes (ENTRY_MAX at most)
#   traffic light head (4 words): x, y (fx), lights + 1 as for edges,
#     height / 4 (fx);
#     cells as buildings, header 37 count, 38 table, 39 cells, 40 lists
#   point (3 words): x, y, height in deck levels / 4 (fx)
#   segment (9 words): a.xy, b.xy, half width, arc length at a (all fx),
#     kind (bits 0-3: 0 a strip of road, 2 a dashed centre line, 4 a
#     footpath (PATHS: paths and service roads are only drawn), 5 a
#     waterway (WATERWAYS), 6 a triangle of a junction's area, its third
#     corner in place of half width and arc length and that corner's
#     height * 256 in bits 12-23), 7 a wall (WALLS), its height in decks for
#     the heights); bits 4-7
#     layer + 2; bit 8 bridge; on a strip bits 9-11: of a connector, one
#     that gives way, one on a ring). Layers come from the OSM layer / bridge /
#     tunnel tags; a bridge deck stands DECK_H metres per layer and its
#     shadow falls along SHADOW, so cells also list the segments whose
#     shadow reaches them; then the heights at a and b / 4 (fx). Roads off a
#     bridge ramp down one level per RAMP metres.
#   cell (2 words): list start, count (into the cell lists)
#   parked car (3 words): x, y (fx), heading in 4096ths of a turn; cells
#     as buildings, header 33 count, 34 table, 35 cells, 36 cell lists
#   green (7 words): first corner, corner count, kind (0 lawn, 1 park, 2
#     woods, 3 water), bounds min.xy max.xy (fx); corners and cells as buildings,
#     header 28 count, 29 table, 30 corners, 31 cells, 32 cell lists
#   building (7 words): first corner, corner count, height (fx, screen
#     units), footprint bounds min.xy max.xy (fx); corner (2 words): x, y (fx). Building cells (2 words, on the
#     road grid) list the buildings whose footprint, roof (BLD_VIEW of its
#     height up the screen) or shadow (BLD_SUN of it along SHADOW) reach
#     them.
#   lights' greens (header 44 start): for each set of lights the green of
#     phase 0 and of phase 1, in tenths of a second
#   terrain (header 43 start): the ground's height (fx, screen units above
#     its lowest) at each corner of the road grid, (nx + 1) * (ny + 1) of
#     them row by row, from Terrarium elevation tiles (DEM_ZOOM, cached in
#     the data dir; 0 for a test map), smoothed over TERRAIN_SMOOTH metres
#     (roads do not follow every bump, nor the grid's)
#     followed, for a map with treeline and snowline (metres; header 21 bit
#     2), by those two (fx, screen units above its lowest ground)
#   way out (header 45 start): for each edge the metres from its start to
#     the nearest end of a lane leaving the map, driving (AWAY if none)
#   spawn weight (header 46 start): for each edge * 16 how strongly cars come
#     in where it crosses the edge of the screen (the OSM spawn tag, e.g. from
#     PATCHES; 1 by default), plus ORPHAN on a lane nothing leads
#     into (cars pull out of its start, there being no other way onto it)
#
# Run: just gen-maps, or by hand:
#      nix-shell -p "python3.withPackages(p: [p.pillow p.numpy])" \
#        --run "python3 gen_maps.py <data dir>"

import hashlib
import heapq
import json
import random
import math
import os
import sys
import time
import urllib.parse
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from collections import defaultdict

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt, gaussian_filter
from shapely import LineString, MultiPoint, Point, Polygon, box, constrained_delaunay_triangles
from shapely.ops import polygonize, unary_union

MAPS = [
    dict(name="Magic Roundabout, Swindon", lat=51.5627, lon=-1.7714, r=95, left=True, max_cars=25),
    dict(name="Arc de Triomphe, Paris", lat=48.8738, lon=2.2950, r=230, left=False, max_cars=110, ring_speed=6),
    dict(name="Spaghetti Junction, Birmingham", lat=52.5095, lon=-1.8594, r=260, left=True, max_cars=168),
    dict(name="Newark Liberty Airport", lat=40.6925, lon=-74.1834, r=360, left=False, max_cars=270),
    dict(name="Katy Freeway, Houston", lat=29.7846, lon=-95.5607, r=380, left=False, max_cars=460),
    dict(name="Central Motorway Junction, Auckland", lat=-36.8620, lon=174.7606, r=380, left=True, max_cars=332),
    dict(name="Sultan Salahuddin Abdul Aziz Shah, Putrajaya", lat=2.9425, lon=101.7010, r=650, left=True, max_cars=130),
    dict(name="Yan'an Road Viaduct, Puxi", lat=31.2264, lon=121.4646, r=300, left=False, max_cars=260),
    dict(name="Nanpu Bridge, Shanghai", lat=31.2102, lon=121.4969, r=320, left=False, max_cars=430),
    dict(name="Diverging Diamond, Springfield MO", lat=37.2504, lon=-93.3107, r=200, left=False, max_cars=140),
    dict(name="Aspernbrücke and Praterstern, Vienna", lat=48.2155, lon=16.3885, r=420, left=False, max_cars=241),
    dict(name="Votivkirche, Vienna", lat=48.2154, lon=16.3591, r=220, left=False, max_cars=123),
    dict(name="Mixing Bowl, Springfield VA", lat=38.7909, lon=-77.1750, r=650, left=False, max_cars=1023),
    dict(name="Squirrel Hill, Pittsburgh", lat=40.4287, lon=-79.9314, r=250, left=False, max_cars=194),
    dict(name="Huangjuewan, Chongqing", lat=29.5877, lon=106.6012, r=330, left=False, max_cars=282),
    dict(name="Central Park South, New York", lat=40.76444, lon=-73.97768, r=300, left=False),
    dict(name="Acropolis, Athens", lat=37.97155, lon=23.73049, r=500, left=False, max_cars=450),
    dict(name="Altstadt, Salzburg", lat=47.7985, lon=13.0460, r=500, left=False, max_cars=199),
    dict(name="Monte Carlo, Monaco", lat=43.7384, lon=7.4246, r=600, left=False, sea=True, max_cars=150),
    dict(name="Le Quesnoy, France", lat=50.248165, lon=3.637365, r=600, left=False, max_cars=120),
    dict(name="Test Junctions", lat=0., lon=0., r=300, left=False, synthetic="junctions"),
    dict(name="Test Splits", lat=0., lon=0., r=300, left=False, synthetic="splits"),
    dict(name="Newark Split A", lat=40.6945, lon=-74.1817, r=60, left=False, crop_of="Newark Liberty Airport"),
    dict(name="Newark Split B", lat=40.6932, lon=-74.1828, r=60, left=False, crop_of="Newark Liberty Airport"),
]

# fixes to the OSM data, by map: ways' tags set (None drops one) and
# nodes moved (lat, lon), applied whenever the data is read so they
# outlast refetches
PATCHES = {
    "Huangjuewan, Chongqing": dict(nodes={}, ways={137433740: dict(layer=None)}),
    "Spaghetti Junction, Birmingham": dict(nodes={}, ways={22924839: dict(deck="2"), 22924841: dict(deck="2")}),
    "Nanpu Bridge, Shanghai": dict(nodes={}, ways={48686765: dict(spawn="4"), 742396769: dict(spawn="4")}),
    "Monte Carlo, Monaco": dict(nodes={}, ways={w: dict(lanes="1") for w in (165636064, 1388331343, 1388331344, 1388331345, 1388331346, 1449972041)}),
    "Newark Liberty Airport": dict(nodes={
        659644538: (40.694644, -74.181514),
        2401095437: (40.694492, -74.181892),
    }, ways={231777461: dict(lifted="yes"), 1529405590: dict(lanes="3"), 1529405589: dict(bridge="yes", layer="1"), 1529405588: dict(bridge="yes")}),
}

CLASSES = ["motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential"]
RANK = {c: 8 - i for i, c in enumerate(CLASSES)}
SPEED = dict(motorway=26, trunk=20, primary=14, secondary=12, tertiary=11, unclassified=9, residential=8)
LANE_W = 3.6
CAR_LEN = 5.0
FETCH = 1.7
BOX = (1.35, 0.65)
W = 1024
FX_OFF, FX_RANGE = 4.0, 8.0
MAX_PTS = 24
GRID = 96
MAX_GIVE = 12
PARK_FILL = 0.6
PARK_ON_ROAD = 0.15
CAR_DRAW = 0.75
PARK_MIN = 3.6
CAR_MIN_DRAW = 0.0082
PARK_CELL = 48
PARK_STREET = dict(parallel=(6., 0.), diagonal=(3.4, 45.), perpendicular=(2.6, 90.))
CONN_PTS = 9
PATHS = dict(footway=1.8, path=1.5, cycleway=2., bridleway=2., steps=1.8, track=3., pedestrian=4.5, service=4.5)
SEG_CELL = 448
EDGE_WORDS = 14
SIG_REACH, SIG_CLUSTER, SIG_HEAD = 30., 35., 1.5
SIG_CELL = 16
HEADER = 47
AWAY = 65535
SIG_CYCLE, SIG_GREEN_MIN, SIG_GREEN_MAX, SIG_WALK = 28., 6., 30., 14.
DEM_ZOOM = 15
DEM_R = 600.
ORPHAN = 1 << 20
COARSE_CLASS = "tertiary"
COARSE_BUILDING = 1500.
TERRAIN_SMOOTH = 25.
DEM_URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png"
SPAWNS = 1024
TURN_RES = 6
STRAIGHT_SHARE = 0.65
STRAIGHT_TURN = 30.
MERGE_TURN = 45.
BRANCH_LOOK = 10.
PATH_TURN = 12.
ENTRY_MAX = 48
PATH_SIMPLE = 0.3
U_TURN = 135.
BACK_TURN = 100.
BACK_NEAR = 2.5
BACK_LOOK = 20.
RING_WOBBLE = 1.3
RING_ROUND = 0.25
RING_COMPACT = 2.
RING_CLEAR = 8.
PATH_KINK = 6.
JUNCTION_SLACK = 0.3
SIDEWALK = 2.
STUB = 12.
JUNCTION_PAD = 1.
JUNCTION_GAP = 0.75
JUNCTION_SIMPLE = 0.3
OUT = ["../../assets/maps.png", "../../../../shell/shaders/assets/maps.png"]
LABEL_OUT = ["../../assets/map_labels.png", "../../../../shell/shaders/assets/map_labels.png"]
LABEL_W, LABEL_H, LABEL_CAP, LABEL_RANGE, LABEL_UP = 1024, 64, 0.4, 0.25, 4
WATERWAYS = dict(river=14., canal=10., stream=3., drain=2., ditch=1.5)
WALLS = dict(city_wall=(9., 8.), retaining_wall=(2., 4.), wall=(1., 2.))
KINDS = ["roads", "buildings", "paths", "green", "water", "parking", "signals", "walls"]
OVERPASS = ["https://overpass.private.coffee/api/interpreter", "https://overpass.kumi.systems/api/interpreter", "https://overpass-api.de/api/interpreter"]
GREEN = dict(leisure=["park", "garden", "playground", "pitch", "golf_course", "common", "recreation_ground", "nature_reserve"],
             landuse=["grass", "forest", "meadow", "recreation_ground", "village_green", "cemetery", "allotments", "orchard"],
             natural=["wood", "scrub", "grassland", "heath"])
WOODS = {"forest", "wood", "scrub", "orchard"}
GREEN_MAX_V = 48
GREEN_CELL = 24
MAX_LANES = 12
TAPER, TAPER_MIN, TAPER_MAX = 8., 12., 40.
MERGE_MIN = 20.
BEND_CUT = 0.8
PINCH_MAX = 80.
MERGE_MAX = 80.
MERGE_APART = 0.85
MARK_MIN = 30.
MAX_MARKED = 6
BLD_VIEW = 0.55
BLD_SUN = 0.7
BLD_DEFAULT = 11.
BLD_MAX_V = 20
BLD_CELL = 48
SHADOW = (0.6, -0.8)
DECK_H = 5.
RAMP = 70.
CAR_EVERY = 85.
MAX_CARS = 1023


def fx(v):
    return int(round((v + FX_OFF) / FX_RANGE * (1 << 24)))


def synthetic(m, what):
    """the test map: rows of hand-made junctions (metres from the centre,
    every road one-way left to right), no buildings or greens"""
    if what != "roads":
        return []
    els, ids = [], {}

    def node(p):
        key = (round(p[0], 1), round(p[1], 1))
        ids.setdefault(key, len(ids) + 1)
        return ids[key]

    def way(pts, lanes, extra=None):
        els.append(dict(type="way", id=len(els) + 1, tags=dict(dict(highway="motorway", oneway="yes", lanes=str(lanes)), **(extra or {})),
                        nodes=[node(p) for p in pts], geometry=[dict(lat=p[1] / 110540, lon=p[0] / 111320) for p in pts]))

    if m["synthetic"] == "splits":
        rows = ((3, 2, 1, ""), (2, 1, 1, ""), (4, 2, 2, ""), (2, 2, 1, ""), (3, 2, 1, "kink"), (4, 2, 2, "deck"))
        for row, (n_in, n_a, n_b, style) in enumerate(rows):
            for col, ang in enumerate((10, 20, 37, 60)):
                cx, cy = -270 + 180 * col, 250 - 100 * row
                at = (cx - 20, cy)
                deck = dict(bridge="yes", layer="1") if style == "deck" else {}
                way([(cx - 90, cy), at], n_in, deck)
                way([at, (cx + 70, cy)], n_a, deck)
                a = math.radians(ang)
                p1 = (at[0] + 20 * math.cos(a), at[1] - 20 * math.sin(a))
                if style == "kink":
                    p2 = (p1[0] + 12 * math.cos(a * 0.3), p1[1] - 12 * math.sin(a * 0.3))
                    way([at, p1], n_b); way([p1, p2], n_b); way([p2, (cx + 70, p2[1])], n_b)
                elif style == "deck":
                    way([at, p1], n_b, deck)
                    way([p1, (p1[0] + 40 * math.cos(a), p1[1] - 40 * math.sin(a))], n_b)
                    way([(cx - 60, cy + 30), (cx - 60, cy - 30)], 1, dict(oneway="no"))
                else:
                    way([at, p1, (p1[0] + 40 * math.cos(a), p1[1] - 40 * math.sin(a))], n_b)
        return els

    def fan(y, sign):
        return [(0, y), (150, y + sign * 12), (300, y + sign * 28), (900, y + sign * 40)]

    def join(y, sign):
        return [(-900, y + sign * 40), (-300, y + sign * 28), (-150, y + sign * 12), (0, y)]
    for y, kind in ((250, "split"), (160, "merge"), (70, "merge3"), (-20, "stub"), (-120, "zip"), (-220, "exit")):
        if kind == "split":
            way([(-900, y), (0, y)], 2); way([(0, y), (900, y)], 1); way(fan(y, -1), 1)
        elif kind in ("merge", "zip", "merge3"):
            n_in, n_out = {"merge": (1, 2), "zip": (1, 1), "merge3": (2, 3)}[kind]
            way([(-900, y), (0, y)], n_in); way(join(y, 1), n_in); way([(0, y), (900, y)], n_out)
        elif kind == "stub":
            way([(-900, y), (-20, y)], 3); way([(-20, y), (20, y)], 1)
            way([(20, y), (900, y)], 2); way([(20, y), (170, y - 12), (320, y - 28), (900, y - 40)], 2)
        else:
            way([(-900, y), (0, y)], 3); way([(0, y), (900, y)], 2); way(fan(y, -1), 1)
    return els


def fetch(m, data, what="roads"):
    """OSM elements round a map (cached in data); a test map makes its own,
    a close-up (crop_of) takes the ones of the map it is cut from"""
    if m.get("synthetic"):
        return synthetic(m, what)
    if m.get("crop_of"):
        return fetch(next(p for p in MAPS if p["name"] == m["crop_of"]), data, what)
    path = os.path.join(data, "%.4f_%.4f_%d%s.json" % (m["lat"], m["lon"], m["r"], "" if what == "roads" else "_" + what))
    if not os.path.exists(path):
        hw = "|".join(CLASSES + [c + "_link" for c in CLASSES[:5]])
        around = "(around:%d,%f,%f)" % (m["r"] * FETCH * 1.5, m["lat"], m["lon"])
        if what == "roads":
            sel = 'way["highway"~"^(%s)$"]%s;' % (hw, around)
        elif what == "parking":
            sel = ('(way["amenity"="parking_space"]%s;node["amenity"="parking_space"]%s;'
                   'way["amenity"="parking"]%s;relation["amenity"="parking"]%s;);') % ((around,) * 4)
        elif what == "coastline":
            sel = 'way["natural"="coastline"]%s;' % around
        elif what == "water":
            sel = ("(way[\"natural\"=\"water\"]%s;relation[\"natural\"=\"water\"]%s;way[\"waterway\"]%s;"
                   "way[\"landuse\"~\"^(reservoir|basin)$\"]%s;relation[\"waterway\"=\"riverbank\"]%s;);") % ((around,) * 5)
        elif what == "paths":
            sel = 'way["highway"~"^(%s)$"]%s;' % ("|".join(PATHS), around)
        elif what == "signals":
            sel = 'node["highway"="traffic_signals"]%s;' % around
        elif what == "walls":
            sel = 'way["barrier"~"^(%s)$"]%s;' % ("|".join(WALLS), around)
        elif what == "buildings":
            sel = 'way["building"]%s;' % around
        else:
            sel = "(" + "".join('%s["%s"~"^(%s)$"]%s;' % (t, k, "|".join(v), around)
                                for t in ("way", "relation") for k, v in GREEN.items()) + ");"
        q = '[out:json][timeout:120];%sout geom;' % sel
        for attempt in range(6):
            url = OVERPASS[(attempt + (KINDS + ["coastline"]).index(what)) % len(OVERPASS)]
            req = urllib.request.Request(url, data=urllib.parse.urlencode({"data": q}).encode(),
                                         headers={"User-Agent": "gloxwald-shader-gen/1.0"})
            try:
                with urllib.request.urlopen(req, timeout=180) as f:
                    body = f.read()
                json.loads(body)
                open(path, "wb").write(body)
                break
            except (OSError, ValueError) as err:
                print("  %s: %s, retrying" % (url, err))
                time.sleep(5 * (attempt + 1))
        else:
            raise SystemExit("overpass unreachable")
        time.sleep(2)
    els = json.load(open(path))["elements"]
    patch = PATCHES.get(m["name"], {})
    for e in els:
        for k, v in patch.get("ways", {}).get(e.get("id"), {}).items():
            if v is None:
                e.get("tags", {}).pop(k, None)
            else:
                e.setdefault("tags", {})[k] = v
        for i, n in enumerate(e.get("nodes", [])):
            if n in patch.get("nodes", {}) and "geometry" in e:
                e["geometry"][i] = dict(lat=patch["nodes"][n][0], lon=patch["nodes"][n][1])
    # a coarse map (one seen from far off) keeps only what shows from there:
    # roads from COARSE_CLASS up, town walls, no paths or parking
    if m.get("coarse"):
        if what in ("paths", "parking"):
            return []
        if what == "roads":
            els = [e for e in els if RANK.get(e.get("tags", {}).get("highway", "").replace("_link", ""), 0) >= RANK[COARSE_CLASS]]
        if what == "walls":
            els = [e for e in els if e.get("tags", {}).get("barrier") == "city_wall"]
    return els


def flow(rank):
    """how strongly traffic keeps to a road of this class: motorways 6,
    residential streets 1"""
    return max(1, round(2 ** ((rank - 4) / 1.5)))


def norm(v):
    l = math.hypot(*v)
    return (v[0] / l, v[1] / l) if l > 1e-12 else (0., 0.)


def plen(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def offset(pts, d):
    out = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        t = norm((b[0] - a[0], b[1] - a[1]))
        out.append((p[0] + t[1] * d, p[1] - t[0] * d))
    return out


def trim(pts, a, b):
    """cut length a off the start and b off the end"""
    def cut(pts, a):
        acc = 0.
        for i in range(len(pts) - 1):
            l = math.dist(pts[i], pts[i + 1])
            if acc + l >= a:
                f = (a - acc) / l if l > 0 else 0
                p = (pts[i][0] + (pts[i + 1][0] - pts[i][0]) * f, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * f)
                return [p] + pts[i + 1:]
            acc += l
        return pts[-1:]
    pts = cut(pts, a)
    return cut(pts[::-1], b)[::-1]


def line_dist(p, pts):
    best = 1e9
    for a, b in zip(pts, pts[1:]):
        ab = (b[0] - a[0], b[1] - a[1])
        l2 = ab[0] ** 2 + ab[1] ** 2 or 1e-12
        t = max(0., min(1., ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / l2))
        best = min(best, math.dist(p, (a[0] + ab[0] * t, a[1] + ab[1] * t)))
    return best


def apart(pts, other, need, step, limit):
    """how far back from its end a line first lies need from another"""
    rev = pts[::-1]
    x, total = 0., plen(rev)
    while x <= min(limit, total):
        if line_dist(trim(rev, x, 0.)[0], other) >= need:
            return x
        x += step
    return min(limit, total)


def simplify(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    ab = (b[0] - a[0], b[1] - a[1])
    l = math.hypot(*ab) or 1e-12
    dmax, k = 0, 0
    for i in range(1, len(pts) - 1):
        d = abs((pts[i][0] - a[0]) * ab[1] - (pts[i][1] - a[1]) * ab[0]) / l
        if d > dmax:
            dmax, k = d, i
    if dmax < eps:
        return [a, b]
    return simplify(pts[:k + 1], eps)[:-1] + simplify(pts[k:], eps)


def chaikin(pts, n=3):
    """round the corners off a polyline, keeping its ends"""
    for _ in range(n):
        if len(pts) < 3:
            return pts
        out = [pts[0]]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        out.append(pts[-1])
        pts = out
    return pts


def resample(pts, n):
    """n points evenly spaced along a polyline"""
    total = plen(pts)
    out, i, acc = [], 0, 0.
    for k in range(n):
        x = total * k / (n - 1)
        while i < len(pts) - 2 and acc + math.dist(pts[i], pts[i + 1]) < x:
            acc += math.dist(pts[i], pts[i + 1])
            i += 1
        seg = math.dist(pts[i], pts[i + 1]) or 1e-12
        f = max(0., min(1., (x - acc) / seg))
        out.append((pts[i][0] + (pts[i + 1][0] - pts[i][0]) * f, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * f))
    return out


def dedupe(pts, eps):
    """drop points closer than eps to the last kept one, keeping both ends"""
    out = [pts[0]]
    for p in pts[1:-1]:
        if math.dist(p, out[-1]) >= eps:
            out.append(p)
    if len(pts) > 1:
        if len(out) > 1 and math.dist(pts[-1], out[-1]) < eps:
            out.pop()
        out.append(pts[-1])
    return out


def end_dir(pts, at_end, u):
    """the direction a polyline leaves its end (at_end) or start, over at
    least half a metre"""
    seq = pts[::-1] if at_end else pts
    a = seq[0]
    for b in seq[1:]:
        if math.dist(a, b) > 0.5 * u:
            break
    d = norm((a[0] - b[0], a[1] - b[1]) if at_end else (b[0] - a[0], b[1] - a[1]))
    return d if d != (0., 0.) else (1., 0.)


def seg_cross(p1, p2, q1, q2):
    def o(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return o(p1, p2, q1) * o(p1, p2, q2) < 0 and o(q1, q2, p1) * o(q1, q2, p2) < 0


def poly_cross(a, b):
    for i in range(len(a) - 1):
        for j in range(len(b) - 1):
            if seg_cross(a[i], a[i + 1], b[j], b[j + 1]):
                return True
    return False


def rings(e):
    """the outer rings of a way or multipolygon relation, as lists of
    {lat, lon}: a relation's outer ways are joined end to end"""
    if e.get("type") == "way":
        return [e["geometry"]] if "geometry" in e else []
    parts = [list(mb["geometry"]) for mb in e.get("members", []) if mb.get("role") == "outer" and mb.get("geometry")]
    out = []
    key = lambda p: (round(p["lat"], 7), round(p["lon"], 7))
    while parts:
        ring = parts.pop()
        for _ in range(len(parts) + 1):
            if key(ring[0]) == key(ring[-1]):
                break
            for i, q in enumerate(parts):
                if key(q[0]) == key(ring[-1]):
                    ring += q[1:]
                elif key(q[-1]) == key(ring[-1]):
                    ring += q[::-1][1:]
                else:
                    continue
                parts.pop(i)
                break
            else:
                break
        out.append(ring)
    return out


def polygon(geom, m, kx, ky, u, max_v):
    """a ring of {lat, lon} in screen units, simplified to at most max_v
    corners, or None if it is off the map or tiny"""
    pts = [((p["lon"] - m["lon"]) * kx, (p["lat"] - m["lat"]) * ky) for p in geom]
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
    if len(pts) < 3:
        return None
    if max(p[0] for p in pts) < -BOX[0] or min(p[0] for p in pts) > BOX[0] or max(p[1] for p in pts) < -BOX[1] or min(p[1] for p in pts) > BOX[1]:
        return None
    if abs(sum(pts[i][0] * pts[i - 1][1] - pts[i - 1][0] * pts[i][1] for i in range(len(pts)))) / 2 / u / u < 25:
        return None
    far = max(range(len(pts)), key=lambda i: math.dist(pts[0], pts[i]))
    eps = 0.4
    while True:
        ring = simplify(pts[:far + 1], eps * u)[:-1] + simplify(pts[far:] + [pts[0]], eps * u)[:-1]
        if len(ring) <= max_v or eps > 50:
            break
        eps *= 1.5
    ring = [(max(-3.5, min(3.5, x)), max(-3.5, min(3.5, y))) for x, y in ring]
    return ring if len(ring) >= 3 else None


def in_box(p):
    return abs(p[0]) < BOX[0] and abs(p[1]) < BOX[1]


def to_edge(p, q):
    """where the segment from p (in the box) to q (out of it) leaves the box"""
    t = 1.
    for k in (0, 1):
        if abs(q[k]) >= BOX[k]:
            t = min(t, (math.copysign(BOX[k] * 0.999, q[k]) - p[k]) / (q[k] - p[k]))
    return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)


def box_runs(pts):
    """the stretches of a line inside the box, cut off at its edge"""
    runs, run, prev = [], [], None
    for p in pts + [None]:
        if p is not None and in_box(p):
            if not run and prev is not None:
                run.append(to_edge(p, prev))
            run.append(p)
        else:
            if run and p is not None:
                run.append(to_edge(run[-1], p))
            if len(run) > 1:
                runs.append(run)
            run = []
        prev = p
    return runs


def inside(pts, p):
    c = False
    for i in range(len(pts)):
        a, b = pts[i - 1], pts[i]
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]:
            c = not c
    return c


def parked(m, data, kx, ky, u, road_els):
    """parked cars (x, y, heading): one in each mapped parking space, rows
    along the aisles of lots (or across lots without aisles; lots mapped as
    multipolygons too), and along the sides of roads tagged with street
    parking (far enough out that the amp as drawn clears the kerb). Every place is filled first, none within PARK_MIN metres of
    another (or the drawn size, CAR_MIN_DRAW screen units, on maps where
    cars are drawn bigger than life) so their amps never overlap"""
    P = lambda g: ((g["lon"] - m["lon"]) * kx, (g["lat"] - m["lat"]) * ky)
    cars, taken = [], {}
    gap = max(PARK_MIN, CAR_MIN_DRAW / u)

    def put(x, y, ang, rnd):
        if abs(x) > BOX[0] or abs(y) > BOX[1]:
            return
        key = (int(x / (gap * u)), int(y / (gap * u)))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for q in taken.get((key[0] + dx, key[1] + dy), []):
                    if math.dist(q, (x, y)) < gap * u:
                        return
        taken.setdefault(key, []).append((x, y))
        cars.append((x, y, ang))

    random.seed(int(m["lat"] * 1000) ^ int(m["lon"] * 1000))
    els = fetch(m, data, "parking")
    aisles = []
    for e in fetch(m, data, "paths"):
        if e.get("type") == "way" and e["tags"].get("highway") == "service" and "geometry" in e:
            aisles.append([P(g) for g in e["geometry"]])
    road_lines = aisles + [[P(g) for g in e["geometry"]] for e in road_els if "geometry" in e]

    def nearest_dir(p):
        best, d = 1e9, (1., 0.)
        for line in road_lines:
            for i in range(len(line) - 1):
                a, b = line[i], line[i + 1]
                ab = (b[0] - a[0], b[1] - a[1])
                l2 = ab[0] ** 2 + ab[1] ** 2 or 1e-12
                t = max(0., min(1., ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / l2))
                dd = math.dist(p, (a[0] + ab[0] * t, a[1] + ab[1] * t))
                if dd < best:
                    best, d = dd, norm(ab)
        return d

    spaces = []
    for e in els:
        t = e.get("tags", {})
        if t.get("amenity") != "parking_space":
            continue
        if e["type"] == "node":
            p = P(e)
            d = nearest_dir(p)
            spaces.append(p)
            put(p[0], p[1], math.atan2(-d[0], d[1]), True)
        elif "geometry" in e:
            pts = [P(g) for g in e["geometry"]]
            if len(pts) > 1 and pts[0] == pts[-1]:
                pts = pts[:-1]
            if len(pts) < 3:
                continue
            cx, cy = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
            longest = max(range(len(pts)), key=lambda i: math.dist(pts[i - 1], pts[i]))
            a, b = pts[longest - 1], pts[longest]
            spaces.append((cx, cy))
            put(cx, cy, math.atan2(b[1] - a[1], b[0] - a[0]), True)

    lots = []
    for e in els:
        t = e.get("tags", {})
        if t.get("amenity") != "parking" or t.get("parking") in ("multi-storey", "underground", "rooftop"):
            continue
        lots += [[P(g) for g in ring] for ring in rings(e)]
    for lot in lots:
        if len(lot) < 3:
            continue
        rows = []
        for line in aisles:
            for i in range(len(line) - 1):
                a, b = line[i], line[i + 1]
                if inside(lot, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)):
                    rows.append((a, b))
        if not rows:
            longest = max(range(len(lot)), key=lambda i: math.dist(lot[i - 1], lot[i]))
            a, b = lot[longest - 1], lot[longest]
            d = norm((b[0] - a[0], b[1] - a[1]))
            n = (-d[1], d[0])
            proj = [(p[0] - a[0]) * n[0] + (p[1] - a[1]) * n[1] for p in lot]
            for off in range(int(min(proj) / (16 * u)) - 1, int(max(proj) / (16 * u)) + 2):
                o = off * 16 * u
                rows.append(((a[0] + n[0] * o - d[0] * 500 * u, a[1] + n[1] * o - d[1] * 500 * u),
                             (a[0] + n[0] * o + d[0] * 500 * u, a[1] + n[1] * o + d[1] * 500 * u)))
        for a, b in rows:
            d = norm((b[0] - a[0], b[1] - a[1]))
            n = (-d[1], d[0])
            L = math.dist(a, b)
            for k in range(int(L / (2.6 * u)) + 1):
                for sgn in (-1, 1):
                    x = a[0] + d[0] * k * 2.6 * u + n[0] * sgn * 5.5 * u
                    y = a[1] + d[1] * k * 2.6 * u + n[1] * sgn * 5.5 * u
                    if inside(lot, (x, y)):
                        put(x, y, math.atan2(n[1], n[0]), True)

    for e in road_els:
        t = e.get("tags", {})
        if "geometry" not in e:
            continue
        for side, sgn in (("left", 1), ("right", -1)):
            kind = None
            for k in ("parking:%s:orientation" % side, "parking:both:orientation", "parking:lane:%s" % side, "parking:lane:both"):
                if t.get(k) in PARK_STREET:
                    kind = t[k]
                    break
            if kind is None and t.get("parking:%s" % side, t.get("parking:both")) in ("lane", "street_side", "on_kerb", "half_on_kerb"):
                kind = "parallel"
            if kind is None:
                continue
            step, ang = PARK_STREET[kind]
            try:
                half = float(t.get("width", "").replace("m", "").strip()) / 2
            except ValueError:
                half = max(1, int(t.get("lanes", "2").split(";")[0] or 2)) * LANE_W / 2
            reach = half + max(1.1 if kind == "parallel" else 2.6, 0.5 * max(CAR_LEN * CAR_DRAW, CAR_MIN_DRAW / u))
            pts = [P(g) for g in e["geometry"]]
            acc = 0.
            total = plen(pts)
            for i in range(len(pts) - 1):
                a, b = pts[i], pts[i + 1]
                L = math.dist(a, b)
                if L <= 0:
                    continue
                d = norm((b[0] - a[0], b[1] - a[1]))
                n = (-d[1] * sgn, d[0] * sgn)
                x0 = (-acc) % (step * u)
                while x0 < L:
                    at = acc + x0
                    if 10 * u < at < total - 10 * u:
                        x, y = a[0] + d[0] * x0 + n[0] * reach * u, a[1] + d[1] * x0 + n[1] * reach * u
                        hd = math.atan2(d[1], d[0]) + math.radians(ang) * (1 if sgn > 0 else -1)
                        put(x, y, hd, True)
                    x0 += step * u
                acc += L
    return cars


def greens(m, data, kx, ky, u):
    """green areas: (corners, kind: 0 lawn, 1 park, 2 woods)"""
    out = []
    for e in fetch(m, data, "green"):
        t = e.get("tags", {})
        vals = {t.get(k) for k in GREEN}
        kind = 2 if vals & WOODS else 1 if t.get("leisure") in ("park", "garden", "common", "nature_reserve") or t.get("landuse") == "cemetery" else 0
        for g in rings(e):
            ring = polygon(g, m, kx, ky, u, GREEN_MAX_V)
            if ring:
                out.append((ring, kind))
    for e in fetch(m, data, "water"):
        t = e.get("tags", {})
        if t.get("waterway") in WATERWAYS:
            continue
        for g in rings(e):
            ring = polygon(g, m, kx, ky, u, GREEN_MAX_V)
            if ring:
                out.append((ring, 3))
    out += [(ring, 3) for ring in sea(m, data, kx, ky)]
    out.sort(key=lambda r: r[1])
    return out


def sea(m, data, kx, ky):
    """the sea round a map with sea=True, as triangles: OSM draws the coast
    as lines with the land on their left, so the map's box cut along them
    falls into pieces that are sea where the coast nearest them has them on
    its right"""
    if not m.get("sea"):
        return []
    lines = [LineString([((p["lon"] - m["lon"]) * kx, (p["lat"] - m["lat"]) * ky) for p in e["geometry"]])
             for e in fetch(m, data, "coastline") if e.get("type") == "way" and len(e.get("geometry", [])) > 1]
    frame = box(-BOX[0], -BOX[1], BOX[0], BOX[1])
    if not lines:
        return []
    pieces = list(polygonize(unary_union([frame.boundary] + [l.intersection(frame) for l in lines])))
    water = []
    for piece in pieces:
        p = piece.representative_point()
        best = min(lines, key=lambda l: l.distance(p))
        d = best.project(p)
        a, b = best.interpolate(max(d - 1e-4, 0.)), best.interpolate(min(d + 1e-4, best.length))
        q = best.interpolate(d)
        if (b.x - a.x) * (p.y - q.y) - (b.y - a.y) * (p.x - q.x) < 0:
            water.append(piece)
    area = unary_union(water).simplify(1e-4)
    return [list(t.exterior.coords)[:3] for t in constrained_delaunay_triangles(area).geoms]


def buildings(m, data, kx, ky, u):
    """footprints (screen units, at most BLD_MAX_V corners) and heights
    (screen units: the height tag, else levels * 3.2 m, else BLD_DEFAULT)"""
    out = []
    for e in fetch(m, data, "buildings"):
        if e.get("type") != "way" or "geometry" not in e:
            continue
        t = e.get("tags", {})
        if t.get("location") == "underground" or t.get("layer", "0").lstrip("-").isdigit() and int(t.get("layer", "0")) < 0:
            continue
        g = e["geometry"]
        pts = [((p["lon"] - m["lon"]) * kx, (p["lat"] - m["lat"]) * ky) for p in g]
        if len(pts) > 1 and pts[0] == pts[-1]:
            pts = pts[:-1]
        if len(pts) < 3 or not any(abs(p[0]) < BOX[0] and abs(p[1]) < BOX[1] for p in pts):
            continue
        area = abs(sum(pts[i][0] * pts[i - 1][1] - pts[i - 1][0] * pts[i][1] for i in range(len(pts)))) / 2 / u / u
        if area < (COARSE_BUILDING if m.get("coarse") else 25):
            continue
        eps = 0.4
        far = max(range(len(pts)), key=lambda i: math.dist(pts[0], pts[i]))
        while True:
            ring = simplify(pts[:far + 1], eps * u)[:-1] + simplify(pts[far:] + [pts[0]], eps * u)[:-1]
            if len(ring) <= BLD_MAX_V or eps > 20:
                break
            eps *= 1.6
        if len(ring) < 3:
            continue
        t = e.get("tags", {})
        h = None
        try:
            h = float(t.get("height", "").replace("m", "").strip())
        except ValueError:
            pass
        if h is None:
            try:
                h = float(t.get("building:levels", "")) * 3.2 + 1.5
            except ValueError:
                h = BLD_DEFAULT
        out.append((ring, max(3., min(h, 200.)) * u))
    return out


def elevation(data, lat, lon, zoom=DEM_ZOOM):
    """metres above sea level at a point, from a Terrarium tile at zoom
    (fetched once into data/dem)"""
    n = 2 ** zoom
    fx_ = (lon + 180) / 360 * n
    fy_ = (1 - math.log(math.tan(math.radians(lat)) + 1 / math.cos(math.radians(lat))) / math.pi) / 2 * n
    tx, ty = int(fx_), int(fy_)
    key = (zoom, tx, ty)
    if key not in DEM_TILES:
        path = os.path.join(data, "dem", "%d_%d_%d.png" % (zoom, tx, ty))
        if not os.path.exists(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            req = urllib.request.Request(DEM_URL % (zoom, tx, ty), headers={"User-Agent": "gloxwald-shader-gen/1.0"})
            with urllib.request.urlopen(req, timeout=60) as f:
                open(path, "wb").write(f.read())
        a = np.asarray(Image.open(path).convert("RGB")).astype(np.float64)
        DEM_TILES[key] = a[..., 0] * 256 + a[..., 1] + a[..., 2] / 256 - 32768
    t = DEM_TILES[key]
    x, y = (fx_ - tx) * 255, (fy_ - ty) * 255
    x0, y0 = int(x), int(y)
    x1, y1 = min(x0 + 1, 255), min(y0 + 1, 255)
    ax, ay = x - x0, y - y0
    return (t[y0, x0] * (1 - ax) + t[y0, x1] * ax) * (1 - ay) + (t[y1, x0] * (1 - ax) + t[y1, x1] * ax) * ay


DEM_TILES = {}


def build(m, data):
    # a new map's queries all go out at once, each starting on its own mirror
    kinds = KINDS + (["coastline"] if m.get("sea") else [])
    with ThreadPoolExecutor(len(kinds)) as pool:
        list(pool.map(lambda what: fetch(m, data, what), kinds))
    els = fetch(m, data)
    lat0, lon0, R = m["lat"], m["lon"], m["r"]
    u = 1. / (2 * R)
    kx = math.cos(math.radians(lat0)) * 111320 * u
    ky = 110540 * u
    lane_w = LANE_W * u

    nodes = {}
    ways = []
    for e in els:
        t = e["tags"]
        hw = t["highway"]
        base = hw.replace("_link", "")
        ids = e["nodes"]
        for nid, g in zip(ids, e["geometry"]):
            nodes[nid] = ((g["lon"] - lon0) * kx, (g["lat"] - lat0) * ky)
        ow = t.get("oneway", "no")
        ring = t.get("junction") in ("roundabout", "circular")
        oneway = 1 if ow in ("yes", "true", "1") or ring or hw in ("motorway", "motorway_link") else -1 if ow == "-1" else 0
        if oneway == -1:
            ids = ids[::-1]
            oneway = 1
        rank = RANK[base] - (0.5 if hw.endswith("_link") else 0)
        bridge = t.get("bridge", "no") not in ("no",)
        tunnel = t.get("tunnel", "no") not in ("no",)
        try:
            layer = int(float(t.get("layer", "1" if bridge else "-1" if tunnel else "0")))
        except ValueError:
            layer = 1 if bridge else 0
        layer = max(-2, min(5, layer if bridge or tunnel else min(layer, 0)))
        def count(k):
            try:
                return max(1, min(MAX_LANES, int(float(t.get(k, "").split(";")[0]))))
            except ValueError:
                return 0
        total = count("lanes")
        if oneway:
            nf, nb = total or 1, 0
        else:
            nf = count("lanes:forward") or max(1, total // 2)
            nb = count("lanes:backward") or max(1, total - nf if total else 1)
            if ow == "-1":
                nf, nb = nb, nf
        try:
            width = float(t.get("width:carriageway", t.get("width", "")).replace("m", "").strip())
            width = width if 2.5 <= width <= 80 else None
        except ValueError:
            width = None
        if width and not oneway:
            wf, wb = width * nf / (nf + nb), width * nb / (nf + nb)
        else:
            wf, wb = width or nf * LANE_W, nb * LANE_W
        w = dict(oneway=oneway, ring=ring, rank=rank, name=t.get("name", ""), speed=(m["ring_speed"] if ring and "ring_speed" in m else SPEED[base] * (0.7 if hw.endswith("_link") else 1)) * u, hw=hw,
                 layer=layer, bridge=bridge, nf=nf, nb=nb, wf=wf * u, wb=wb * u, keep=t.get("lifted") == "yes", deck=int(t.get("deck", "0")), spawn=float(t.get("spawn", "1")))
        run, prev = [], None
        for n in ids + [None]:
            if n is not None and in_box(nodes[n]):
                if not run and prev is not None:
                    nodes[(n, prev)] = to_edge(nodes[n], nodes[prev])
                    run.append((n, prev))
                run.append(n)
            else:
                if run and n is not None:
                    nodes[(run[-1], n)] = to_edge(nodes[run[-1]], nodes[n])
                    run.append((run[-1], n))
                if len(run) > 1:
                    ways.append(dict(w, ids=run))
                run = []
            prev = n

    # a bridge over nothing drawn (a stream, a railway) stays on the
    # ground: a deck only lifts if some piece of its viaduct (bridge ways
    # joined end to end) crosses a road or path below it (or a patch says
    # lifted=yes: one shortened by a moved node). OSM layers only
    # order what crosses what (pieces of one viaduct are tagged anything
    # from 1 to 5), so a lifted deck stands one level over the highest
    # deck it crosses (lowest first), at least 1
    def lines_cross(a, b):
        if min(p[0] for p in a) > max(p[0] for p in b) or min(p[0] for p in b) > max(p[0] for p in a):
            return False
        if min(p[1] for p in a) > max(p[1] for p in b) or min(p[1] for p in b) > max(p[1] for p in a):
            return False
        return any(seg_cross(p, q, r, t) for p, q in zip(a, a[1:]) for r, t in zip(b, b[1:]))
    below = [(w["layer"], [nodes[n] for n in w["ids"]], w) for w in ways]
    for e in fetch(m, data, "paths"):
        if e.get("type") == "way" and "geometry" in e and e["tags"].get("bridge", "no") == "no":
            below.append((0, [((g["lon"] - lon0) * kx, (g["lat"] - lat0) * ky) for g in e["geometry"]], None))
    decks = [w for w in ways if w["bridge"]]
    group = list(range(len(decks)))
    def root(k):
        while group[k] != k:
            group[k] = group[group[k]]
            k = group[k]
        return k
    at_node = defaultdict(list)
    for k, w in enumerate(decks):
        for n in (w["ids"][0], w["ids"][-1]):
            at_node[n].append(k)
    for ks in at_node.values():
        for k in ks[1:]:
            group[root(k)] = root(ks[0])
    lifted, crossed = set(), {}
    for k, w in enumerate(decks):
        pts = [nodes[n] for n in w["ids"]]
        crossed[k] = [o for layer, line, o in below if layer < w["layer"] and lines_cross(pts, line)]
        if crossed[k] or w["keep"]:
            lifted.add(root(k))
    level = {}
    for k in sorted(range(len(decks)), key=lambda k: decks[k]["layer"]):
        if root(k) in lifted:
            level[id(decks[k])] = min(5, max([1, decks[k]["deck"]] + [level.get(id(o), 0) + 1 for o in crossed[k] if o is not None]))
    for k, w in enumerate(decks):
        if root(k) in lifted:
            w["layer"] = level[id(w)]
        else:
            w["bridge"], w["layer"] = False, 0

    use = defaultdict(int)
    for w in ways:
        for i, n in enumerate(w["ids"]):
            use[n] += 2 if i in (0, len(w["ids"]) - 1) else 1
    junction = {n for n, c in use.items() if c >= 2}

    roads = []
    for w in ways:
        ids = w["ids"]
        start = 0
        for i in range(1, len(ids)):
            if ids[i] in junction or i == len(ids) - 1:
                if i > start:
                    roads.append(dict(w, ids=ids[start:i + 1]))
                start = i

    # a short one-way piece with fewer lanes than the piece before it and
    # the pieces after it leave room for (less any roads merging in there)
    # is often a mistagged stub (3, 1, 2 lanes): it gets as many, so it is
    # no bottleneck
    by_start, by_end = defaultdict(list), defaultdict(list)
    for r in roads:
        by_start[r["ids"][0]].append(r)
        by_end[r["ids"][-1]].append(r)
    for _ in range(3):
        for r in roads:
            a, b = r["ids"][0], r["ids"][-1]
            if not r["oneway"] or len(by_end[a]) != 1 or len(by_start[a]) != 1 or not by_start[b]:
                continue
            p, qs = by_end[a][0], by_start[b]
            if not p["oneway"] or not all(q["oneway"] for q in qs) or plen([nodes[n] for n in r["ids"]]) > PINCH_MAX * u:
                continue
            want = min(p["nf"], sum(q["nf"] for q in qs) - sum(o["nf"] for o in by_end[b] if o is not r))
            if r["nf"] < want:
                r["wf"] = r["wf"] * want / r["nf"]
                r["nf"] = want

    # directed lanes
    side = -1 if m["left"] else 1
    lanes = []
    for ri, r in enumerate(roads):
        pts = chaikin([nodes[n] for n in r["ids"]])
        dirs = [(r["ids"], pts)] if r["oneway"] else [(r["ids"], pts), (r["ids"][::-1], pts[::-1])]
        for k, (ids, p) in enumerate(dirs):
            n, rw = (r["nb"], r["wb"]) if k else (r["nf"], r["wf"])
            p = p if r["oneway"] else offset(p, side * 0.5 * rw)
            lanes.append(dict(road=ri, a=ids[0], b=ids[-1], pts=p, rank=r["rank"], speed=r["speed"], ring=r["ring"], oneway=r["oneway"], rev=k,
                              layer=r["layer"], bridge=r["bridge"], n=n, rw=rw, spawn=r["spawn"]))

    # roundabouts: small cycles of one-way lanes on one level that turn one
    # way all round, once, and either all bear one name (as the Magic
    # Roundabout's do) and are compact (perimeter squared over 4 pi area
    # under RING_COMPACT, not a dual carriageway joined at both ends) or are
    # round (their distances from their centre spread by under RING_ROUND
    # of the mean): not a knot of ramps in an interchange, nor one-way
    # streets round a block
    def round_once(path):
        pts = dedupe([q for j in path for q in lanes[j]["pts"]], 0.5 * u)
        if math.dist(pts[0], pts[-1]) < 0.5 * u:
            pts = pts[:-1]
        if len(pts) < 3:
            return False
        turns = [math.atan2((b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]), (b[0] - a[0]) * (c[0] - b[0]) + (b[1] - a[1]) * (c[1] - b[1]))
                 for a, b, c in zip(pts[-1:] + pts[:-1], pts, pts[1:] + pts[:1])]
        net, total = abs(sum(turns)), sum(abs(t) for t in turns)
        even = resample(pts + pts[:1], 64)
        cx, cy = sum(q[0] for q in even) / len(even), sum(q[1] for q in even) / len(even)
        rs = [math.hypot(q[0] - cx, q[1] - cy) for q in even]
        names = {roads[lanes[j]["road"]]["name"] for j in path}
        area = abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(even, even[1:] + even[:1]))) / 2
        compact = area > 0 and plen(even) ** 2 / (4 * math.pi * area) < RING_COMPACT
        known = len(names) == 1 and "" not in names and compact or (max(rs) - min(rs)) < RING_ROUND * sum(rs) / len(rs)
        return (abs(math.degrees(net) - 360) < 60 and total < net * RING_WOBBLE and known
                and len({lanes[j]["layer"] for j in path}) == 1)
    out_of = defaultdict(list)
    for i, l in enumerate(lanes):
        out_of[l["a"]].append(i)
    for i, l in enumerate(lanes):
        if not l["oneway"] or l["ring"]:
            continue
        best = None
        stack = [(i, l["b"], plen(l["pts"]), [i])]
        while stack and best is None:
            cur, node, length, path = stack.pop()
            if length > 160 * u * 2:
                continue
            for j in out_of[node]:
                lj = lanes[j]
                if not lj["oneway"]:
                    continue
                if j == i:
                    best = path
                    break
                if j not in path and len(path) < 10:
                    stack.append((j, lj["b"], length + plen(lj["pts"]), path + [j]))
        if best and round_once(best):
            for j in best:
                lanes[j]["ring"] = True

    # heights: a bridge deck stands at its layer, but where decks of
    # different layers join end to end (viaducts come in pieces) the joint
    # sits at their mean and each deck eases back to its own level; roads
    # leading off a bridge slope down one layer per RAMP metres, along the
    # network (each node gets the highest height any bridge end reaches it
    # with)
    H = defaultdict(float)
    decks = defaultdict(list)
    for r in roads:
        if r["bridge"] and r["layer"] > 0:
            for n in (r["ids"][0], r["ids"][-1]):
                decks[n].append(float(r["layer"]))
    for n, t in decks.items():
        H[n] = sum(t) / len(t)
    fixed = set(decks)
    rlen = [plen([nodes[n] for n in r["ids"]]) / u for r in roads]
    for _ in range(50):
        changed = False
        for ri, r in enumerate(roads):
            if r["bridge"]:
                continue
            a, b = r["ids"][0], r["ids"][-1]
            for x, y in ((a, b), (b, a)):
                h = H[x] - rlen[ri] / RAMP
                if y not in fixed and h > H[y] + 1e-6:
                    H[y] = h
                    changed = True
        if not changed:
            break

    def ease(d, x):
        return math.copysign(max(0., abs(d) - x / RAMP), d)

    def height(l, x):
        if l["bridge"] and l["layer"] > 0:
            t = float(l["layer"])
            return t + ease(H[l["a"]] - t, x) + ease(H[l["b"]] - t, l["len0"] - x)
        return max(0., H[l["a"]] - x / RAMP, H[l["b"]] - (l["len0"] - x) / RAMP)

    # trim at junctions
    width_at = defaultdict(float)
    deg = defaultdict(set)
    for r_i, r in enumerate(roads):
        hwid = (r["wf"] + (0 if r["oneway"] else r["wb"])) * 0.5
        for n in (r["ids"][0], r["ids"][-1]):
            width_at[n] = max(width_at[n], hwid)
            deg[n].add(r_i)
    # where a road just continues into the next piece but changes width
    # (lanes added or dropped), both ends are cut back so the connector
    # between them is a taper, TAPER metres per metre of width change;
    # where one-way roads merge into one (or one splits) the wide road is
    # cut back by as much (MERGE_MIN at least) and the narrow ones back to
    # where they still lie MERGE_APART of their widths apart (MERGE_MAX at
    # most: OSM draws them meeting at a point), so they run on side by side
    # into its lanes;
    # and where one piece runs on into the next round a bend, or a branch
    # turns off a split, both are cut back BEND_CUT metres per degree of it
    # (a third of the piece at most) so the connector rounds it off. A split
    # or merge is one whose branches all lie within MERGE_TURN of the lane
    # they leave or join; one-way streets meeting at a sharper corner are
    # an ordinary junction
    starts, ends = defaultdict(list), defaultdict(list)
    for l in lanes:
        starts[l["a"]].append(l)
        ends[l["b"]].append(l)

    def gentle(ins, outs):
        for a in ins:
            for b in outs:
                t1, t2 = end_dir(a["pts"], True, u), end_dir(b["pts"], False, u)
                if math.degrees(math.acos(max(-1., min(1., t1[0] * t2[0] + t1[1] * t2[1])))) > MERGE_TURN:
                    return False
        return True

    def cut(l, at_end):
        node = l["b"] if at_end else l["a"]
        wide = starts[node] if not at_end else ends[node]
        narrow = ends[node] if not at_end else starts[node]
        oneways = all(p["oneway"] for p in wide + narrow) and gentle(ends[node], starts[node])
        if len(wide) == 1 and len(narrow) > 1 and oneways:
            dw = abs(sum(p["rw"] for p in narrow) - l["rw"]) / u
            return min(max(TAPER * dw, MERGE_MIN), TAPER_MAX) * u
        if narrow and len(wide) > 1 and oneways:
            pts = l["pts"] if at_end else l["pts"][::-1]
            back = 0.
            for p in wide:
                if p is not l:
                    other = p["pts"] if at_end else p["pts"][::-1]
                    back = max(back, apart(pts, other, MERGE_APART * 0.5 * (l["rw"] + p["rw"]), u, MERGE_MAX * u))
            if len(narrow) == 1:
                t1 = end_dir(narrow[0]["pts"] if not at_end else l["pts"], True, u)
                t2 = end_dir(l["pts"] if not at_end else narrow[0]["pts"], False, u)
                bend = math.degrees(math.acos(max(-1., min(1., t1[0] * t2[0] + t1[1] * t2[1]))))
                back = max(back, min(BEND_CUT * bend * u, plen(l["pts"]) / 3))
            return max(back, min(max(width_at[node] * 1.6, 5 * u), 14 * u))
        if len(deg[node]) > 2:
            return min(max(width_at[node] * 1.6, 5 * u), 14 * u)
        partners = [p for p in (starts[node] if at_end else ends[node]) if p["road"] != l["road"]]
        dw = max([abs(p["rw"] - l["rw"]) for p in partners] + [0.]) / u
        bend = 0.
        for p in partners:
            t1 = end_dir(l["pts"] if at_end else p["pts"], True, u)
            t2 = end_dir(p["pts"] if at_end else l["pts"], False, u)
            bend = max(bend, math.degrees(math.acos(max(-1., min(1., t1[0] * t2[0] + t1[1] * t2[1])))))
        smooth = min(BEND_CUT * bend * u, plen(l["pts"]) / 3)
        if dw < 0.4:
            return max(0.4 * u, smooth)
        return max(0.5 * min(max(TAPER * dw, TAPER_MIN), TAPER_MAX) * u, smooth)

    # (a lane cut back at both ends keeps a fifth of itself; the end where
    # it runs side by side into a merge or out of a split keeps its cut
    # first)
    side_cut = lambda l, at_end: (len(starts[l["b"] if at_end else l["a"]]) > 1) != (len(ends[l["b"] if at_end else l["a"]]) > 1)
    # a road meeting a ring (OSM joins it to the ring's centre line) ends
    # no further in than the ring's edge, RING_CLEAR metres out from it
    def clear(l, at_end):
        node = l["b"] if at_end else l["a"]
        rings = [p["rw"] for p in starts[node] + ends[node] if p["ring"]]
        return 0. if l["ring"] or not rings else 0.5 * max(rings) + RING_CLEAR * u
    cuts = [(max(cut(l, False), clear(l, False)), max(cut(l, True), clear(l, True))) for l in lanes]
    for l, (ta, tb) in zip(lanes, cuts):
        L = plen(l["pts"])
        if ta + tb > L * 0.8:
            sa, sb = side_cut(l, False), side_cut(l, True)
            if sb and not sa:
                tb = min(tb, L * 0.8)
                ta = min(ta, L * 0.8 - tb)
            elif sa and not sb:
                ta = min(ta, L * 0.8)
                tb = min(tb, L * 0.8 - ta)
            else:
                f = L * 0.8 / (ta + tb)
                ta, tb = ta * f, tb * f
        l["head"], l["tail"] = trim(l["pts"], 0., L - ta), trim(l["pts"], L - tb, 0.)
        l["pts"] = dedupe(simplify(trim(l["pts"], ta, tb), 0.15 * u), 0.3 * u)
        l["len0"] = L / u
        hs, x = [], ta / u
        for i, q in enumerate(l["pts"]):
            if i:
                x += math.dist(l["pts"][i - 1], q) / u
            hs.append(height(l, x))
        l["h"] = hs

    # connectors (one where a road just runs on into the next, as at a
    # change of width, is drawn on the one of their layers nearer the
    # ground, so its taper is part of that surface rather than a wedge of
    # its own)
    into = defaultdict(list)
    for i, l in enumerate(lanes):
        into[l["b"]].append(i)
    conns = []
    for n, ins in into.items():
        outs = out_of.get(n, [])
        for i in ins:
            li = lanes[i]
            cands = [o for o in outs if not (lanes[o]["road"] == li["road"] and lanes[o]["rev"] != li["rev"])]
            if not cands and not isinstance(n, tuple):
                cands = outs
            t0 = end_dir(li["pts"], True, u)
            turns = {}
            for o in cands:
                t2 = end_dir(lanes[o]["pts"], False, u)
                turns[o] = math.degrees(math.atan2(t0[0] * t2[1] - t0[1] * t2[0], t0[0] * t2[0] + t0[1] * t2[1]))
            # turns sharper than U_TURN, or than BACK_TURN onto a road that
            # BACK_LOOK metres on still runs within BACK_NEAR road widths of
            # this one (back along the other side of a dual carriageway), go
            # where the lane has a gentler one
            def back(o):
                lo = lanes[o]
                q = trim(lo["pts"], min(BACK_LOOK * u, 0.9 * plen(lo["pts"])), 0.)[0]
                near = BACK_NEAR * 0.5 * (li["rw"] + lo["rw"])
                return abs(turns[o]) > U_TURN or abs(turns[o]) > BACK_TURN and line_dist(q, li["pts"]) < near
            keep = [o for o in cands if not back(o)] or sorted(cands, key=lambda o: abs(turns[o]))[:1]
            for o in keep:
                lo = lanes[o]
                p0, p2 = li["pts"][-1], lo["pts"][0]
                t2 = end_dir(lo["pts"], False, u)
                turn = turns[o]
                h0, h1 = li["h"][-1], lo["h"][0]
                conns.append(dict(node=n, i=i, o=o, p0=p0, p2=p2, t2=t2, offin=0., offout=0., h=[h0 + (h1 - h0) * k / (CONN_PTS - 1) for k in range(CONN_PTS)], turn=turn, t0=t0,
                                  layer=min(li["layer"], lo["layer"], key=abs) if len(ins) == 1 and len(outs) == 1 else max(li["layer"], lo["layer"]),
                                  bridge=li["bridge"] or lo["bridge"], n=li["n"], nout=lo["n"], rw=li["rw"], rwout=lo["rw"],
                                  ring=li["ring"] and lo["ring"], entering=lo["ring"] and not li["ring"],
                                  rank=li["rank"], speed=min(li["speed"], lo["speed"]) * (0.55 if abs(turn) > 40 else 0.9)))

    # every connector is one lane, from a lane of the road in to a lane of
    # the road out. The ways on out of a road share its lanes from the
    # driving side across in the order they lie (seen from its end, where
    # each is BRANCH_LOOK metres on; on the right first under right-hand
    # traffic): a turn gets as many lanes as the road it goes
    # into has (off a ring just the outer one, the ring itself going on in
    # all its lanes), the ways straight on (within
    # STRAIGHT_TURN) the rest, each at least one (more ways than lanes share
    # them). A turn to the driving side keeps to that side of the road it
    # goes into, one across to the far side, straight on a lane stays the
    # lane it is counted from the driving side, and lanes with no lane left
    # to go to squeeze into the last; lanes going into a road with more
    # lanes than they are, the only road going into it or onto a ring,
    # fan out over all of them in order (4 into 12: each to 3). So no two
    # connectors out of one road cross, and cars change lanes on the roads
    # only
    side = -1 if m["left"] else 1
    lat_of = lambda l, j: side * (0.5 * l["rw"] - (j + 0.5) * l["rw"] / l["n"])
    lane_at = lambda l, off: min(range(l["n"]), key=lambda j: abs(lat_of(l, j) - off))
    by_in = defaultdict(list)
    for c in conns:
        by_in[c["i"]].append(c)
    plans = []
    for i, cs in by_in.items():
        li = lanes[i]
        n = li["n"]
        def bearing(c):
            pts = lanes[c["o"]]["pts"]
            q = pts[min(len(pts) - 1, next((k for k in range(len(pts)) if plen(pts[:k + 1]) > BRANCH_LOOK * u), len(pts) - 1))]
            d = (q[0] - c["p0"][0], q[1] - c["p0"][1])
            t = c["t0"]
            return math.atan2(t[0] * d[1] - t[1] * d[0], t[0] * d[0] + t[1] * d[1]) * side
        cs.sort(key=bearing)
        k = len(cs)
        straight = [abs(c["turn"]) < STRAIGHT_TURN for c in cs]
        if k > n:
            spans = [(j * n // k, 1) for j in range(k)]
        else:
            cnt, rem = [1] * k, n - k
            for want in (True, False):
                for j in range(k):
                    if straight[j] == want:
                        lo = lanes[cs[j]["o"]]
                        add = min(rem, (1 if li["ring"] and not lo["ring"] else lo["n"]) - cnt[j])
                        if add > 0:
                            cnt[j] += add
                            rem -= add
            pool = [j for j in range(k) if straight[j]] or list(range(k))
            while rem > 0:
                for j in pool:
                    if rem:
                        cnt[j] += 1
                        rem -= 1
            spans, acc = [], 0
            for j in range(k):
                spans.append((acc, cnt[j]))
                acc += cnt[j]
        if li["ring"]:
            spans = [(0, n) if lanes[c["o"]]["ring"] else sp for c, sp in zip(cs, spans)]
        plans += [(c, st, a, cn) for c, st, (a, cn) in zip(cs, straight, spans)]
    # one-way roads merging into one (each within MERGE_TURN of straight,
    # not a ring, which keeps its lanes as they are, joined onto)
    # share its lanes out side by side, in the order they lie across it:
    # lane for lane where they bring as many as it has, fanned out where
    # fewer, squeezed where more
    merged, into = {}, defaultdict(list)
    for pl in plans:
        into[pl[0]["o"]].append(pl)
    for o, pls in into.items():
        lo = lanes[o]
        if len(pls) < 2 or not lo["oneway"] or lo["ring"] and any(lanes[pl[0]["i"]]["ring"] for pl in pls) or not all(lanes[pl[0]["i"]]["oneway"] and abs(pl[0]["turn"]) < MERGE_TURN for pl in pls):
            continue
        t, at = pls[0][0]["t2"], lo["pts"][0]
        across = lambda pl: side * ((pl[0]["p0"][0] - at[0]) * t[1] - (pl[0]["p0"][1] - at[1]) * t[0])
        pls.sort(key=across, reverse=True)
        total, g, no = sum(pl[3] for pl in pls), 0, lo["n"]
        for pl in pls:
            for q in range(pl[3]):
                merged[(id(pl[0]), q)] = range(g * no // total, (g + 1) * no // total) if total <= no else [g * no // total]
                g += 1
    feeders = defaultdict(set)
    for c, st, a, cn in plans:
        feeders[c["o"]].add(c["i"])
    per_lane = []
    for c, st, a, cn in plans:
        li, n = lanes[c["i"]], lanes[c["i"]]["n"]
        lo = lanes[c["o"]]
        no = lo["n"]
        for q in range(cn):
            j = a + q
            if (id(c), q) in merged:
                jos = merged[(id(c), q)]
            elif cn < no and (len(feeders[c["o"]]) == 1 or lo["ring"] and not li["ring"]):
                jos = range(q * no // cn, (q + 1) * no // cn)
            elif st or c["turn"] * side < 0:
                jos = [min(q, no - 1)]
            else:
                jos = [max(no - cn + q, 0)]
            for jo in jos:
                oi, oo = lat_of(li, j), lat_of(lo, jo)
                r0, r2 = (c["t0"][1], -c["t0"][0]), (c["t2"][1], -c["t2"][0])
                per_lane.append(dict(c, n=1, nout=1, rw=li["rw"] / n, rwout=lo["rw"] / no, offin=oi, offout=oo, share=max(cn, no), take=cn,
                                     p0=(c["p0"][0] + r0[0] * oi, c["p0"][1] + r0[1] * oi),
                                     p2=(c["p2"][0] + r2[0] * oo, c["p2"][1] + r2[1] * oo)))
    conns = per_lane
    def shape(c, fit=None, avoid=None, shrinks=(1., 0.85, 0.7, 0.6, 0.5)):
        """going on more or less straight a connector follows the road it
        stands in for (the trimmed end of the lane in, then the trimmed
        start of the lane out, where that has no corner over PATH_KINK
        degrees), moving across from its start offset to its end one on
        the way; turning, it is a cubic leaving along the lane in and arriving
        along the lane out, its handles as long for every lane of the turn
        (set by the distance between the middles of the two roads, so the
        lanes of a bend stay side by side), cut short (to half at most, any
        tighter and they fold) only as far as it takes to
        lie inside fit and keep its lane clear of avoid. Either way the
        heading (and a car's sideways offset) is continuous through the
        junction; True if it turns"""
        p0, p2, t0, t2 = c["p0"], c["p2"], c["t0"], c["t2"]
        li, lo = lanes[c["i"]], lanes[c["o"]]
        base = chaikin(dedupe(li["tail"] + lo["head"][1:], 0.2 * u), 2)
        bends = [abs(math.degrees(math.atan2((b[0] - a[0]) * (d[1] - b[1]) - (b[1] - a[1]) * (d[0] - b[0]), (b[0] - a[0]) * (d[0] - b[0]) + (b[1] - a[1]) * (d[1] - b[1]))))
                 for a, b, d in zip(base, base[1:], base[2:])]
        if abs(c["turn"]) < PATH_TURN and len(base) > 1 and plen(base) > 2 * u and not c.get("joined") and not c.get("cubic") and max(bends, default=0.) < PATH_KINK:
            k_n = max(CONN_PTS, min(MAX_PTS, int(plen(base) / (4 * u)) + 2))
            pts = resample(base, k_n)
            c["pts"] = []
            for k, p in enumerate(pts):
                f = k / (k_n - 1)
                lat = c["offin"] + (c["offout"] - c["offin"]) * f * f * (3 - 2 * f)
                d = norm((pts[min(k + 1, k_n - 1)][0] - pts[max(k - 1, 0)][0], pts[min(k + 1, k_n - 1)][1] - pts[max(k - 1, 0)][1]))
                c["pts"].append((p[0] + d[1] * lat, p[1] - d[0] * lat))
            c["h"] = [c["h"][0] + (c["h"][-1] - c["h"][0]) * k / (k_n - 1) for k in range(k_n)]
            return False
        c0 = (p0[0] - t0[1] * c["offin"], p0[1] + t0[0] * c["offin"])
        c2 = (p2[0] - t2[1] * c["offout"], p2[1] + t2[0] * c["offout"])
        hl0 = max(math.dist(c0, c2) * 0.4, lane_w * 1.2 if abs(c["turn"]) >= 150 else 0.)
        for shrink in shrinks:
            c["shrink"] = shrink
            hl = hl0 * shrink
            q0 = (p0[0] + t0[0] * hl, p0[1] + t0[1] * hl)
            q1 = (p2[0] - t2[0] * hl, p2[1] - t2[1] * hl)
            c["pts"] = []
            for k in range(CONN_PTS):
                f = k / (CONN_PTS - 1)
                w0, w1, w2, w3 = (1 - f) ** 3, 3 * (1 - f) ** 2 * f, 3 * (1 - f) * f * f, f ** 3
                c["pts"].append((w0 * p0[0] + w1 * q0[0] + w2 * q1[0] + w3 * p2[0], w0 * p0[1] + w1 * q0[1] + w2 * q1[1] + w3 * p2[1]))
            line = LineString(c["pts"])
            if (fit is None or fit.contains(line)) and (avoid is None or not avoid.intersects(line.buffer(0.5 * c["rw"]))):
                break
        return True

    # each junction's area: where its connectors run (half a lane either
    # side of them), within the hull of the ends of the lanes meeting
    # there, less buildings and parks, woods and water and a SIDEWALK
    # round them (keeping the piece that is most of it). A turn keeps its
    # full sweep (the asphalt drawn grows to take it) unless its lane runs
    # into one of those, when it is drawn tighter
    turning = [shape(c) for c in conns]
    # the connectors out of one lane are drawn alike (all cubics if any is),
    # so one following the road never bows across the others
    kinds = defaultdict(set)
    for c, t in zip(conns, turning):
        kinds[c["i"]].add(t)
    for k, (c, t) in enumerate(zip(conns, turning)):
        if not t and len(kinds[c["i"]]) > 1:
            c["cubic"] = True
            turning[k] = shape(c)
    obst = [Polygon(p).buffer(0) for p, _ in buildings(m, data, kx, ky, u) if len(p) >= 3]
    obst += [Polygon(p).buffer(0) for p, k in greens(m, data, kx, ky, u) if k >= 1 and len(p) >= 3]
    obst = unary_union(obst).buffer(SIDEWALK * u) if obst else None
    at_node = defaultdict(list)
    for c in conns:
        at_node[c["node"]].append(c)
    areas, fits = {}, {}
    for nd, cs in at_node.items():
        ends = []
        for c in cs:
            for p, t, w in ((c["p0"], c["t0"], c["rw"]), (c["p2"], c["t2"], c["rwout"])):
                ends += [(p[0] + t[1] * w / 2, p[1] - t[0] * w / 2), (p[0] - t[1] * w / 2, p[1] + t[0] * w / 2)]
        hull = MultiPoint(ends).convex_hull
        if hull.geom_type != "Polygon":
            continue
        area = hull.intersection(unary_union([LineString(c["pts"]).buffer(0.5 * max(c["rw"], c["rwout"]) + 0.5 * lane_w) for c in cs]))
        if obst is not None:
            area = area.difference(obst)
        if area.geom_type == "MultiPolygon":
            area = max(area.geoms, key=lambda g: g.area)
        if area.is_empty or area.geom_type != "Polygon":
            continue
        areas[nd], fits[nd] = area, area.buffer(JUNCTION_SLACK * lane_w)
    for c, t in zip(conns, turning):
        if t and obst is not None and obst.intersects(LineString(c["pts"]).buffer(0.5 * c["rw"])):
            shape(c, avoid=obst)
    # the lanes of one turn share the tightest of their curves, so they
    # stay evenly side by side
    tight = defaultdict(lambda: 1.)
    for c, t in zip(conns, turning):
        if t:
            tight[(c["i"], c["o"])] = min(tight[(c["i"], c["o"])], c.get("shrink", 1.))
    for c, t in zip(conns, turning):
        if t and c.get("shrink", 1.) != tight[(c["i"], c["o"])]:
            shape(c, shrinks=(tight[(c["i"], c["o"])],))

    # junctions with a lane under STUB metres lying all inside their areas
    # (a stub between two close junctions, the ring of a mini roundabout)
    # are one intersection: those lanes go, and each way through it, lane
    # by lane, becomes one connector across its whole area (no U-turns);
    # where one of those would not fit in the area or would cut across a
    # building or park, the junctions stay apart
    def collapse(internal):
        group = {}
        find = lambda n: n if group.get(n, n) == n else find(group[n])
        for k in internal:
            ra, rb = find(lanes[k]["a"]), find(lanes[k]["b"])
            if ra != rb:
                group[rb] = ra
        out_of_lane = defaultdict(list)
        for c in conns:
            out_of_lane[c["i"]].append(c)
        joined, seen = [], set()
        for c in conns:
            if c["i"] in internal or c["o"] not in internal:
                continue
            stack = [(c, 0)]
            while stack:
                cc, depth = stack.pop()
                if cc["o"] not in internal:
                    li, lo = lanes[c["i"]], lanes[cc["o"]]
                    key = (c["i"], round(c["offin"], 6), cc["o"], round(cc["offout"], 6))
                    t0, t2 = c["t0"], cc["t2"]
                    turn = math.degrees(math.atan2(t0[0] * t2[1] - t0[1] * t2[0], t0[0] * t2[0] + t0[1] * t2[1]))
                    if key in seen or abs(turn) > U_TURN or li["road"] == lo["road"] and li["rev"] != lo["rev"]:
                        continue
                    seen.add(key)
                    joined.append(dict(c, o=cc["o"], p2=cc["p2"], t2=t2, offout=cc["offout"], rwout=cc["rwout"], turn=turn, joined=True,
                                       ring=li["ring"] and lo["ring"], entering=lo["ring"] and not li["ring"], rank=li["rank"],
                                       layer=max(c["layer"], cc["layer"]), bridge=c["bridge"] or cc["bridge"],
                                       h=[c["h"][0] + (cc["h"][-1] - c["h"][0]) * k / (CONN_PTS - 1) for k in range(CONN_PTS)],
                                       speed=min(li["speed"], lo["speed"]) * (0.55 if abs(turn) > 40 else 0.9)))
                    continue
                if depth < 6:
                    j = lane_at(lanes[cc["o"]], cc["offout"])
                    stack += [(x, depth + 1) for x in out_of_lane[cc["o"]] if lane_at(lanes[cc["o"]], x["offin"]) == j]
        cs = [dict(c) for c in conns if c["i"] not in internal and c["o"] not in internal] + joined
        ways = defaultdict(int)
        for c in cs:
            ways[(c["i"], c["o"])] += 1
        for c in cs:
            c["group"] = find(c["node"])
            if c.get("joined"):
                c["share"] = ways[(c["i"], c["o"])]
        members = defaultdict(list)
        for nd, area in areas.items():
            members[find(nd)].append(area)
        for k in internal:
            members[find(lanes[k]["a"])].append(LineString(lanes[k]["pts"]).buffer(0.5 * lanes[k]["rw"]))
        ar, ft = {}, {}
        for g, parts in members.items():
            area = unary_union(parts)
            if area.geom_type == "MultiPolygon":
                area = max(area.geoms, key=lambda x: x.area)
            ar[g], ft[g] = area, area.buffer(JUNCTION_SLACK * lane_w)
        bad = set()
        for c in cs:
            if c.get("joined"):
                shape(c, ft.get(c["group"]), obst)
                line = LineString(c["pts"])
                if c["group"] in ft and not ft[c["group"]].contains(line) or obst is not None and obst.intersects(line.buffer(0.5 * c["rw"])):
                    bad.add(c["group"])
        return cs, ar, ft, bad, find
    internal = set()
    for k, l in enumerate(lanes):
        A, B = areas.get(l["a"]), areas.get(l["b"])
        if A is not None and B is not None and len(l["pts"]) > 1 and plen(l["pts"]) < STUB * u and A.union(B).buffer(0.5 * lane_w).contains(LineString(l["pts"])):
            internal.add(k)
    if internal:
        cs, ar, ft, bad, find = collapse(internal)
        if bad:
            internal = {k for k in internal if find(lanes[k]["a"]) not in bad}
            cs, ar, ft, _, _ = collapse(internal)
        conns, areas, fits = cs, ar, ft
        keep = [k for k in range(len(lanes)) if k not in internal]
        index = {k: n for n, k in enumerate(keep)}
        lanes = [lanes[k] for k in keep]
        for c in conns:
            c["i"], c["o"] = index[c["i"]], index[c["o"]]
    # every lane into a junction leads on and every lane out of one is led
    # into: a lane left out takes the connector of the nearest lane that
    # has one, moved across to it
    for c in conns:
        c.setdefault("group", c["node"])
    for end, off, pk, tk in ((("i", "offin", "p0", "t0")), (("o", "offout", "p2", "t2"))):
        at_lane = defaultdict(list)
        for c in conns:
            at_lane[c[end]].append(c)
        for k, cs in at_lane.items():
            l = lanes[k]
            have = {lane_at(l, c[off]) for c in cs}
            for j in range(l["n"]):
                if j in have:
                    continue
                nb = min(cs, key=lambda c: abs(lat_of(l, j) - c[off]))
                d, t = lat_of(l, j) - nb[off], nb[tk]
                c = dict(nb, **{off: nb[off] + d, pk: (nb[pk][0] + t[1] * d, nb[pk][1] - t[0] * d)})
                shape(c, avoid=obst)
                conns.append(c)
    at_node = defaultdict(list)
    for c in conns:
        at_node[c["group"]].append(c)

    # traffic lights: each OSM signal belongs to the junction nearest it
    # on the ground (within SIG_REACH), junctions with lights within SIG_CLUSTER of each
    # other (the two carriageways of a road) work as one; every connector
    # taken from a lane coming into the group from outside it is signalled,
    # in phase 0 or 1 by whether its lane comes in along the group's first
    # approach or across it; a head stands by the end of each such lane,
    # on the driving side, else further out, else on the other side: the
    # first of those spots off the asphalt (where carriageways cross, as
    # in a diverging diamond, beside one is on the other). Approaches in
    # one phase whose ways straight on cross (the crossovers of a diverging
    # diamond) are put in different ones
    decked = {n for r in roads if r["bridge"] for n in r["ids"]}
    junctions = [n for n in deg if len(deg[n]) >= 3 and H[n] < 0.3 and n not in decked]
    lit = set()
    for e in fetch(m, data, "signals"):
        if e.get("type") != "node":
            continue
        p = ((e["lon"] - lon0) * kx, (e["lat"] - lat0) * ky)
        best = min(junctions, key=lambda n: math.dist(nodes[n], p), default=None)
        if best is not None and math.dist(nodes[best], p) < SIG_REACH * u:
            lit.add(best)
    lit = sorted(lit, key=str)
    ctrl = {}
    for n in lit:
        near = [ctrl[o] for o in ctrl if math.dist(nodes[o], nodes[n]) < SIG_CLUSTER * u]
        ctrl[n] = min(near) if near else len(set(ctrl.values()))
        for o in list(ctrl):
            if ctrl[o] in near:
                ctrl[o] = ctrl[n]
    ids = {c: k for k, c in enumerate(sorted(set(ctrl.values())))}
    ctrl = {n: ids[c] for n, c in ctrl.items()}
    axis, heads = {}, {}
    for c in conns:
        c["sig"] = -1
        n = c["node"]
        li = lanes[c["i"]]
        if n not in ctrl or li["a"] in ctrl and ctrl[li["a"]] == ctrl[n]:
            continue
        g = ctrl[n]
        t = c["t0"]
        a = axis.setdefault(g, t)
        c["sig"] = g | (0 if abs(t[0] * a[0] + t[1] * a[1]) >= 0.7071 else 1) << 16
        heads[c["i"]] = [li["pts"][-1], (t[1] * side, -t[0] * side), li["rw"], c["sig"], li["h"][-1]]
    lit_c = [c for c in conns if c["sig"] >= 0]
    for _ in range(4):
        moved = False
        for a in lit_c:
            for b in lit_c:
                if a["i"] < b["i"] and a["sig"] == b["sig"] and abs(a["turn"]) < 30 and abs(b["turn"]) < 30 \
                        and a["o"] != b["o"] and poly_cross(a["pts"], b["pts"]):
                    flip = b["sig"] ^ (1 << 16)
                    for c in lit_c:
                        if c["i"] == b["i"]:
                            c["sig"] = flip
                    heads[b["i"]][3] = flip
                    moved = True
        if not moved:
            break
    heads = list(heads.values())

    # who gives way to whom (not across the phases of one set of lights,
    # nor between lanes of one road, nor into different lanes of one road
    # without crossing)
    by_node = defaultdict(list)
    for k, c in enumerate(conns):
        by_node[c["group"]].append(k)
    give = defaultdict(list)
    for n, ks in by_node.items():
        for a in ks:
            for b in ks:
                if a >= b:
                    continue
                ca, cb = conns[a], conns[b]
                if ca["i"] == cb["i"]:
                    continue
                if ca["sig"] >= 0 and cb["sig"] >= 0 and ca["sig"] != cb["sig"]:
                    continue
                crossing = poly_cross(ca["pts"], cb["pts"])
                side_by_side = ca["o"] == cb["o"] and abs(ca["offout"] - cb["offout"]) > 1e-9
                if not (ca["o"] == cb["o"] or crossing) or side_by_side and not crossing:
                    continue
                def first(x, y):
                    """True if x has priority over y"""
                    if x["ring"] != y["ring"]:
                        return x["ring"]
                    if y["entering"] != x["entering"]:
                        return y["entering"]
                    if x["rank"] != y["rank"]:
                        return x["rank"] > y["rank"]
                    sx, sy = abs(x["turn"]) < 30, abs(y["turn"]) < 30
                    if sx != sy:
                        return sx
                    rx = (y["t0"][1], -y["t0"][0])
                    return -x["t0"][0] * rx[0] - x["t0"][1] * rx[1] > 0
                if first(ca, cb):
                    give[b].append(a)
                else:
                    give[a].append(b)

    # edge list: lanes then connectors; a lane lists each connector out of
    # it as often as traffic should take it: each way on by the lanes of
    # this road it takes (TURN_RES times, shared out over its connectors),
    # so a one-lane exit beside four lanes on gets a fifth, except that
    # off a ring the ways straight on (within STRAIGHT_TURN) get at least
    # STRAIGHT_SHARE, so cars do not wander round the block. A road that runs off the map is left there, not turned back
    edges = []
    for l in lanes:
        edges.append(dict(pts=l["pts"], h=l["h"], ring=l["ring"], conn=False, speed=l["speed"], succ=[], give=[], layer=l["layer"], bridge=l["bridge"], rank=l["rank"],
                          n=l["n"], nout=l["n"], rw=l["rw"], rwout=l["rw"], offin=0., offout=0., sig=-1, spawn=l.get("spawn", 1.)))
    weight = [c.get("take", 1) / c["share"] for c in conns]
    out_of_lane = defaultdict(list)
    for k, c in enumerate(conns):
        out_of_lane[c["i"]].append(k)
    for i, ks in out_of_lane.items():
        on = [k for k in ks if abs(conns[k]["turn"]) < STRAIGHT_TURN]
        s, t = sum(weight[k] for k in on), sum(weight[k] for k in ks if k not in on)
        if not lanes[i]["ring"] and s > 0 and t > 0 and s / (s + t) < STRAIGHT_SHARE:
            for k in on:
                weight[k] *= STRAIGHT_SHARE * t / ((1 - STRAIGHT_SHARE) * s)
    for k, c in enumerate(conns):
        edges.append(dict(pts=c["pts"], h=c["h"], ring=c["ring"], conn=True, speed=c["speed"], succ=[c["o"]], give=[len(lanes) + g for g in give[k]][:MAX_GIVE], pred=c["i"],
                          layer=c["layer"], bridge=c["bridge"], n=c["n"], nout=c["nout"], rw=c["rw"], rwout=c["rwout"], offin=c["offin"], offout=c["offout"], sig=c["sig"], spawn=1.))
        edges[-1]["rank"] = lanes[c["o"]]["rank"]
        edges[c["i"]]["succ"] += [len(lanes) + k] * max(1, round(TURN_RES * weight[k]))

    # split long lanes so each edge has at most MAX_PTS points
    final = []
    remap = {}
    for idx, e in enumerate(edges):
        pts, hs = e["pts"], e["h"]
        chunks = []
        while len(pts) > MAX_PTS:
            chunks.append((pts[:MAX_PTS], hs[:MAX_PTS]))
            pts, hs = pts[MAX_PTS - 1:], hs[MAX_PTS - 1:]
        chunks.append((pts, hs))
        remap[idx] = (len(final), len(chunks))
        for ci, (ch, chh) in enumerate(chunks):
            final.append(dict(e, pts=ch, h=chh, chain=ci < len(chunks) - 1, cont=ci > 0))
    for idx, e in enumerate(edges):
        first_i, n = remap[idx]
        for ci in range(n):
            f = final[first_i + ci]
            if ci < n - 1:
                f["succ"] = [first_i + ci + 1]
                f["give"] = []
            else:
                f["succ"] = [remap[s][0] for s in e["succ"]]
                f["give"] = [remap[g][0] + remap[g][1] - 1 for g in e["give"]]
            f["pred"] = remap[e["pred"]][0] + remap[e["pred"]][1] - 1 if "pred" in e and ci == 0 else -1
    # a turn into what never leads off the map (a turning loop the box cut
    # off from its road) is dropped where there is another way on, and
    # nobody starts in there
    back = {}
    for i, e in enumerate(final):
        for s in e["succ"]:
            back.setdefault(s, set()).add(i)
    out = {i for i, e in enumerate(final) if not e["succ"]}
    todo = list(out)
    while todo:
        for p in back.get(todo.pop(), ()):
            if p not in out:
                out.add(p)
                todo.append(p)
    for e in final:
        keep = [s for s in e["succ"] if s in out]
        if keep:
            e["succ"] = keep
    lane_count = sum(remap[i][1] for i in range(len(lanes)))
    has_in = set()
    for e in final:
        for s in e["succ"]:
            has_in.add(s)
    entries = [i for i in range(lane_count) if i in out and not final[i]["conn"] and (abs(final[i]["pts"][0][0]) > 0.95 or abs(final[i]["pts"][0][1]) > 0.55)]
    entries = [i for i in entries for _ in range(min(ENTRY_MAX, flow(final[i]["rank"]) * final[i]["n"]))]

    # render segments: every lane and connector as a strip as wide as its
    # lanes (a connector tapering from one end's to the other's), so the
    # asphalt is exactly where the cars drive, and as dashed line-only
    # pieces the centre line of two-way roads and the lines between lanes
    # (not on roads wider than MAX_MARKED lanes, like the Etoile's ring,
    # nor on pieces shorter than MARK_MIN metres)
    segs = []
    # junction areas as triangles, a set for each layer its connectors
    # are on: just the asphalt they take there (gaps they close in and
    # notches under JUNCTION_GAP lanes filled, outlines to within
    # JUNCTION_SIMPLE metres), shrunk by JUNCTION_PAD, which the shader
    # grows back, so the seams between them never show; each corner as
    # high as the connector nearest it, so a junction climbing to a deck
    # climbs with it
    for nd in areas:
        by_layer = defaultdict(list)
        for c in at_node[nd]:
            by_layer[c["layer"]].append(c)
        for layer, cs in by_layer.items():
            taken = unary_union([LineString(c["pts"]).buffer(0.5 * max(c["rw"], c["rwout"]), cap_style="flat") for c in cs])
            taken = taken.buffer(JUNCTION_GAP * lane_w, cap_style="flat").buffer(-JUNCTION_GAP * lane_w)
            taken = unary_union([Polygon(g.exterior) for g in getattr(taken, "geoms", [taken]) if g.geom_type == "Polygon"])
            inner = taken.buffer(-JUNCTION_PAD * u).simplify(JUNCTION_SIMPLE * u)
            if inner.is_empty:
                continue
            bridge = any(c["bridge"] for c in cs)
            near = np.array([(x, y, h) for c in cs for (x, y), h in zip(c["pts"], c["h"])])
            hat = lambda q: near[np.argmin((near[:, 0] - q[0]) ** 2 + (near[:, 1] - q[1]) ** 2), 2]
            for tri in constrained_delaunay_triangles(inner).geoms:
                pa, pb, pc = tri.exterior.coords[:3]
                segs.append((pa, pb, pc[0], pc[1], 6 | min(4095, int(round(hat(pc) * 256))) << 12, layer, bridge, hat(pa), hat(pb)))
    for ei, e in enumerate(final):
        pts = e["pts"]
        for i in range(len(pts) - 1):
            f = (i + 0.5) / max(len(pts) - 1, 1)
            hw = 0.5 * (e["rw"] + (e["rwout"] - e["rw"]) * f) + 0.05 * lane_w
            flags = (512 if e["conn"] else 0) | (1024 if e["give"] else 0) | (2048 if e["ring"] else 0) | min(4095, ei + 1) << 12
            segs.append((pts[i], pts[i + 1], hw, 0., flags, e["layer"], e["bridge"], e["h"][i], e["h"][i + 1]))

    def dashes(pts, hs, layer, bridge):
        arc = 0.
        for i in range(len(pts) - 1):
            segs.append((pts[i], pts[i + 1], 0., arc, 2, layer, bridge, hs[i], hs[i + 1]))
            arc += math.dist(pts[i], pts[i + 1])
    # markings stop where a road runs onto a roundabout's asphalt
    ring_strips = [(l["pts"], 0.5 * l["rw"] + 1.5 * u) for l in lanes if l["ring"]]

    def on_ring(p):
        return any(line_dist(p, pts) < r for pts, r in ring_strips)

    def off_ring(l):
        pts, L = l["pts"], plen(l["pts"])
        if l["ring"] or not ring_strips:
            return pts, l["h"]
        a = b = 0.
        while a < L and on_ring(trim(pts, a, 0.)[0]):
            a += u
        while b < L - a and on_ring(trim(pts, 0., b)[-1]):
            b += u
        if a == 0. and b == 0.:
            return pts, l["h"]
        if a + b >= L - u:
            return [], []
        q = trim(pts, a, b)
        return q, [l["h"][min(range(len(pts)), key=lambda i: math.dist(pts[i], x))] for x in q]

    for l in lanes:
        pts, hs = off_ring(l)
        if len(pts) < 2 or plen(pts) < MARK_MIN * u:
            continue
        if not l["oneway"] and not l["rev"]:
            dashes(offset(pts, -side * 0.5 * l["rw"]), hs, l["layer"], l["bridge"])
        for k in range(1, l["n"] if l["n"] <= MAX_MARKED else 0):
            dashes(offset(pts, l["rw"] * (k / l["n"] - 0.5)), hs, l["layer"], l["bridge"])

    # waterways as blue ribbons (kind 5) under everything else
    for e in fetch(m, data, "water"):
        t = e.get("tags", {})
        if e.get("type") != "way" or t.get("waterway") not in WATERWAYS or "geometry" not in e:
            continue
        try:
            wid = float(t.get("width", "").replace("m", "").strip())
        except ValueError:
            wid = WATERWAYS[t["waterway"]]
        if t.get("tunnel", "no") != "no":
            continue
        for run in box_runs([((gp["lon"] - lon0) * kx, (gp["lat"] - lat0) * ky) for gp in e["geometry"]]):
            pts = simplify(chaikin(run, 2), PATH_SIMPLE * u)
            for i in range(len(pts) - 1):
                segs.append((pts[i], pts[i + 1], wid * 0.5 * u, 0., 5, 0, False, 0., 0.))

    # paths and service roads, only drawn: service roads as narrow asphalt
    # (kind 0, like the roads), the rest as pale lines (kind 4); like
    # waterways, rounded off and then thinned to within PATH_SIMPLE metres
    for e in fetch(m, data, "paths"):
        if e.get("type") != "way" or "geometry" not in e:
            continue
        t = e["tags"]
        kind = 0 if t["highway"] == "service" else 4
        hwid = PATHS[t["highway"]] * 0.5 * u
        bridge = t.get("bridge", "no") != "no"
        layer = 1 if bridge else 0
        for run in box_runs([((gp["lon"] - lon0) * kx, (gp["lat"] - lat0) * ky) for gp in e["geometry"]]):
            pts = simplify(chaikin(run, 2), PATH_SIMPLE * u)
            for i in range(len(pts) - 1):
                segs.append((pts[i], pts[i + 1], hwid, 0., kind, layer, bridge, float(layer), float(layer)))

    # walls (kind 7): town walls and retaining walls, and a plain wall where
    # named or historic, WALLS[barrier] metres wide and high, kept angular
    # (bastions are corners); their height, in decks, stands where a deck's
    # would, so they cast shadows the same way
    for e in fetch(m, data, "walls"):
        t = e.get("tags", {})
        if e.get("type") != "way" or "geometry" not in e or t.get("barrier") not in WALLS:
            continue
        if t["barrier"] == "wall" and not (t.get("name") or t.get("historic")):
            continue
        wid, high = WALLS[t["barrier"]]
        for run in box_runs([((gp["lon"] - lon0) * kx, (gp["lat"] - lat0) * ky) for gp in e["geometry"]]):
            pts = simplify(run, PATH_SIMPLE * u)
            for i in range(len(pts) - 1):
                segs.append((pts[i], pts[i + 1], wid * 0.5 * u, 0., 7, 0, False, high / DECK_H, high / DECK_H))

    xs = [p[0] for s in segs for p in s[:2]]
    ys = [p[1] for s in segs for p in s[:2]]
    minx, miny = min(xs) - 0.02, min(ys) - 0.02
    cell = max(max(xs) - minx, max(ys) - miny) / GRID
    nx, ny = int((max(xs) - minx) / cell) + 1, int((max(ys) - miny) / cell) + 1
    cells = defaultdict(list)
    for si, (a, b, hw, arc, kind, layer, _, ha, hb) in enumerate(segs):
        if kind & 15 == 6:
            pad = JUNCTION_PAD * u
            x0, x1 = min(a[0], b[0], hw) - pad, max(a[0], b[0], hw) + pad
            y0, y1 = min(a[1], b[1], arc) - pad, max(a[1], b[1], arc) + pad
        else:
            x0, x1 = min(a[0], b[0]) - hw, max(a[0], b[0]) + hw
            y0, y1 = min(a[1], b[1]) - hw, max(a[1], b[1]) + hw
        if max(ha, hb) > 0:
            sx, sy = SHADOW[0] * DECK_H * u * max(ha, hb), SHADOW[1] * DECK_H * u * max(ha, hb)
            x0, x1 = min(x0, x0 + sx), max(x1, x1 + sx)
            y0, y1 = min(y0, y0 + sy), max(y1, y1 + sy)
        for cx in range(int((x0 - minx) / cell), int((x1 - minx) / cell) + 1):
            for cy in range(int((y0 - miny) / cell), int((y1 - miny) / cell) + 1):
                if 0 <= cx < nx and 0 <= cy < ny:
                    cells[(cx, cy)].append(si)

    words = []
    blds = buildings(m, data, kx, ky, u)
    bcells = defaultdict(list)
    for bi, (pts, h) in enumerate(blds):
        x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
        y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
        sx, sy = SHADOW[0] * BLD_SUN * h, SHADOW[1] * BLD_SUN * h
        vy = BLD_VIEW * h
        X0, X1 = min(x0, x0 + sx), max(x1, x1 + sx)
        Y0, Y1 = min(y0, y0 + sy), max(y1 + vy, y1 + sy)
        for cx in range(max(0, int((X0 - minx) / cell)), min(nx, int((X1 - minx) / cell) + 1)):
            for cy in range(max(0, int((Y0 - miny) / cell)), min(ny, int((Y1 - miny) / cell) + 1)):
                bcells[(cx, cy)].append(bi)

    grn = greens(m, data, kx, ky, u)
    gcells = defaultdict(list)
    for gi, (pts, _) in enumerate(grn):
        x0, x1 = min(p[0] for p in pts) - 5 * u, max(p[0] for p in pts) + 5 * u
        y0, y1 = min(p[1] for p in pts) - 5 * u, max(p[1] for p in pts) + 5 * u
        for cx in range(max(0, int((x0 - minx) / cell)), min(nx, int((x1 - minx) / cell) + 1)):
            for cy in range(max(0, int((y0 - miny) / cell)), min(ny, int((y1 - miny) / cell) + 1)):
                gcells[(cx, cy)].append(gi)

    # parked cars: those whose amp covers more than PARK_ON_ROAD of asphalt
    # dropped (the rest are drawn over it), then only PARK_FILL of them kept
    sz = max(CAR_LEN * u * CAR_DRAW, CAR_MIN_DRAW)
    probe = [(i / 3 * 0.5 * sz, j / 3 * 0.5 * sz) for i in range(-3, 4) for j in range(-3, 4) if i * i + j * j <= 9]

    def on_road(x, y):
        near = set()
        for cx in range(int((x - sz - minx) / cell), int((x + sz - minx) / cell) + 1):
            for cy in range(int((y - sz - miny) / cell), int((y + sz - miny) / cell) + 1):
                near.update(cells.get((cx, cy), []))
        near = [segs[i] for i in near if segs[i][4] & 15 == 0]
        hit = 0
        for dx, dy in probe:
            p = (x + dx, y + dy)
            for a, b, hw, *_ in near:
                ab = (b[0] - a[0], b[1] - a[1])
                l2 = ab[0] ** 2 + ab[1] ** 2 or 1e-12
                t = max(0., min(1., ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / l2))
                if math.dist(p, (a[0] + ab[0] * t, a[1] + ab[1] * t)) < hw:
                    hit += 1
                    break
        return hit / len(probe)
    parks = [c for c in parked(m, data, kx, ky, u, els) if on_road(c[0], c[1]) <= PARK_ON_ROAD]
    parks = [c for c in parks if random.random() < PARK_FILL]
    pcells = defaultdict(list)
    reach = CAR_LEN * u
    for pi, (x, y, _) in enumerate(parks):
        for cx in range(max(0, int((x - reach - minx) / cell)), min(nx, int((x + reach - minx) / cell) + 1)):
            for cy in range(max(0, int((y - reach - miny) / cell)), min(ny, int((y + reach - miny) / cell) + 1)):
                pcells[(cx, cy)].append(pi)

    def asphalt(p):
        cx, cy = int((p[0] - minx) / cell), int((p[1] - miny) / cell)
        for i in cells.get((cx, cy), []):
            a, b, hw, _, kind, *_ = segs[i]
            if kind != 0:
                continue
            ab = (b[0] - a[0], b[1] - a[1])
            l2 = ab[0] ** 2 + ab[1] ** 2 or 1e-12
            t = max(0., min(1., ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / l2))
            if math.dist(p, (a[0] + ab[0] * t, a[1] + ab[1] * t)) < hw + 0.5 * u:
                return True
        return False
    placed = []
    for p, right, rw, sg, h in heads:
        spots = [(k, rw * 0.5 + d * u) for k in (1, -1) for d in (SIG_HEAD, SIG_HEAD + 2, SIG_HEAD + 5)]
        spots = [(p[0] + right[0] * k * o, p[1] + right[1] * k * o) for k, o in spots]
        placed.append((next((q for q in spots if not asphalt(q)), spots[0]), sg, h))
    heads = [(q[0], q[1], sg, h) for q, sg, h in placed]
    hcells = defaultdict(list)
    reach = 3 * u
    for hi, (x, y, _, _) in enumerate(heads):
        for cx in range(max(0, int((x - reach - minx) / cell)), min(nx, int((x + reach - minx) / cell) + 1)):
            for cy in range(max(0, int((y - reach - miny) / cell)), min(ny, int((y + reach - miny) / cell) + 1)):
                hcells[(cx, cy)].append(hi)

    hdr = [0] * HEADER
    base = len(words)
    words += hdr
    hdr[0], hdr[1] = lane_count, len(final)
    hdr[2] = len(words)
    for e in final:
        words += [0] * EDGE_WORDS
    hdr[3] = len(words)
    pstart = []
    for e in final:
        pstart.append(len(words) - hdr[3])
        for p, h in zip(e["pts"], e["h"]):
            words += [fx(p[0]), fx(p[1]), fx(h / 4)]
    hdr[4] = len(words)
    sstart = []
    for e in final:
        sstart.append(len(words) - hdr[4])
        words += e["succ"]
    hdr[5] = len(words)
    gstart = []
    for e in final:
        gstart.append(len(words) - hdr[5])
        words += e["give"]
    for k, e in enumerate(final):
        o = hdr[2] + EDGE_WORDS * k
        words[o:o + EDGE_WORDS] = [pstart[k] // 3, len(e["pts"]), fx(plen(e["pts"])), sstart[k], len(e["succ"]),
                          gstart[k], len(e["give"]),
                          (1 if e["conn"] else 0) | (2 if e["ring"] else 0) | (e["layer"] + 2) << 2 | min(255, int(e["speed"] * 1000)) << 8
                          | e["n"] << 16 | e["nout"] << 20, fx(e["rw"]), fx(e["rwout"]), fx(e["offin"]), fx(e["offout"]), e["sig"] + 1 | (1 << 20 if e["cont"] else 0), e["pred"] + 1]
    hdr[6], hdr[7] = len(words), len(entries)
    words += entries
    hdr[8], hdr[9] = len(words), len(segs)
    for a, b, hw, arc, kind, layer, bridge, ha, hb in segs:
        words += [fx(a[0]), fx(a[1]), fx(b[0]), fx(b[1]), fx(hw), fx(arc), kind | (layer + 2) << 4 | (1 if bridge else 0) << 8, fx(ha / 4), fx(hb / 4)]
    hdr[10] = len(words)
    words += [0] * (2 * nx * ny)
    hdr[11] = len(words)
    full = max((len(l) for l in cells.values()), default=0)
    if full > SEG_CELL:
        print("  %d of %d cells over SEG_CELL (worst %d)" % (sum(len(l) > SEG_CELL for l in cells.values()), len(cells), full), flush=True)
    for cy in range(ny):
        for cx in range(nx):
            lst = cells.get((cx, cy), [])
            o = hdr[10] + 2 * (cy * nx + cx)
            words[o:o + 2] = [len(words) - hdr[11], min(len(lst), SEG_CELL)]
            words += lst[:SEG_CELL]
    hdr[12], hdr[13] = nx, ny
    hdr[14], hdr[15], hdr[16] = fx(minx), fx(miny), fx(cell)
    if m.get("synthetic"):
        ground = [0.] * ((nx + 1) * (ny + 1))
    else:
        zoom = max(10, min(DEM_ZOOM, round(DEM_ZOOM - math.log2(max(R, 1.) / DEM_R))))
        ground = [elevation(data, lat0 + (miny + cy * cell) / ky, lon0 + (minx + cx * cell) / kx, zoom) for cy in range(ny + 1) for cx in range(nx + 1)]
    ground = gaussian_filter(np.array(ground).reshape(ny + 1, nx + 1), TERRAIN_SMOOTH * u / cell, mode="nearest").ravel().tolist()
    low = min(ground)
    hdr[43] = len(words)
    words += [fx((g - low) * u) for g in ground]
    if "snowline" in m:
        words += [fx((m["treeline"] - low) * u), fx((m["snowline"] - low) * u)]
    hdr[17], hdr[18] = fx(CAR_LEN * u), fx(2 * R / 1000) if 2 * R < 3900 else fx(-2 * R / 10000)
    hdr[19], hdr[20] = len(words), len(m["name"])
    words += [ord(ch) for ch in m["name"]]
    hdr[21] = (1 if m["left"] else 0) | (2 if m.get("scatter") else 0) | (4 if "snowline" in m else 0)
    total = sum(plen(l["pts"]) * l["n"] for l in lanes)
    cars = m["max_cars"] if "max_cars" in m else total / u / CAR_EVERY
    hdr[22] = max(8, min(MAX_CARS, int(cars)))
    hdr[23], hdr[24] = len(blds), len(words)
    words += [0] * (7 * len(blds))
    hdr[25] = len(words)
    for bi, (pts, h) in enumerate(blds):
        words[hdr[24] + 7 * bi:hdr[24] + 7 * bi + 7] = [(len(words) - hdr[25]) // 2, len(pts), fx(h),
                                                        fx(min(p[0] for p in pts)), fx(min(p[1] for p in pts)),
                                                        fx(max(p[0] for p in pts)), fx(max(p[1] for p in pts))]
        for q in pts:
            words += [fx(q[0]), fx(q[1])]
    hdr[26] = len(words)
    words += [0] * (2 * nx * ny)
    hdr[27] = len(words)
    for cy in range(ny):
        for cx in range(nx):
            lst = bcells.get((cx, cy), [])
            o = hdr[26] + 2 * (cy * nx + cx)
            words[o:o + 2] = [len(words) - hdr[27], min(len(lst), BLD_CELL)]
            words += lst[:BLD_CELL]
    hdr[28], hdr[29] = len(grn), len(words)
    words += [0] * (7 * len(grn))
    hdr[30] = len(words)
    for gi, (pts, kind) in enumerate(grn):
        words[hdr[29] + 7 * gi:hdr[29] + 7 * gi + 7] = [(len(words) - hdr[30]) // 2, len(pts), kind,
                                                        fx(min(p[0] for p in pts)), fx(min(p[1] for p in pts)),
                                                        fx(max(p[0] for p in pts)), fx(max(p[1] for p in pts))]
        for q in pts:
            words += [fx(q[0]), fx(q[1])]
    hdr[31] = len(words)
    words += [0] * (2 * nx * ny)
    hdr[32] = len(words)
    for cy in range(ny):
        for cx in range(nx):
            lst = gcells.get((cx, cy), [])
            o = hdr[31] + 2 * (cy * nx + cx)
            words[o:o + 2] = [len(words) - hdr[32], min(len(lst), GREEN_CELL)]
            words += lst[:GREEN_CELL]
    hdr[33], hdr[34] = len(parks), len(words)
    for x, y, ang in parks:
        words += [fx(x), fx(y), int((ang % (2 * math.pi)) / (2 * math.pi) * 4096) % 4096]
    hdr[35] = len(words)
    words += [0] * (2 * nx * ny)
    hdr[36] = len(words)
    for cy in range(ny):
        for cx in range(nx):
            lst = pcells.get((cx, cy), [])
            o = hdr[35] + 2 * (cy * nx + cx)
            words[o:o + 2] = [len(words) - hdr[36], min(len(lst), PARK_CELL)]
            words += lst[:PARK_CELL]
    weights = [plen(final[i]["pts"]) * final[i]["n"] * flow(final[i]["rank"]) * (i in out) for i in range(lane_count)]
    total_w, acc, spawns = sum(weights) or 1., 0., []
    for i, w in enumerate(weights):
        lo, acc = acc, acc + w
        spawns += [i] * (int(acc / total_w * SPAWNS) - int(lo / total_w * SPAWNS))
    hdr[41], hdr[42] = len(spawns), len(words)
    words += spawns
    hdr[37], hdr[38] = len(heads), len(words)
    for x, y, sg, h in heads:
        words += [fx(x), fx(y), sg + 1, fx(h / 4)]
    # each set of lights shares SIG_CYCLE seconds of green between its two
    # phases by how much traffic comes in on them (the lanes in, each by
    # the flow of its road), SIG_GREEN_MIN to SIG_GREEN_MAX each; a phase
    # no road comes in on (a crossing's, for people on foot) gets SIG_WALK
    demand = defaultdict(float)
    for i, off in {(c["i"], round(c["offin"], 6)): 0 for c in conns if c["sig"] >= 0}:
        for c in conns:
            if c["i"] == i and c["sig"] >= 0:
                demand[(c["sig"] & 65535, c["sig"] >> 16)] += flow(lanes[i]["rank"])
                break
    hdr[44] = len(words)
    for g in range(len(ids)):
        d0, d1 = demand[(g, 0)], demand[(g, 1)]
        share = 0.5 if d0 + d1 == 0 else d0 / (d0 + d1)
        for f, d in ((share, d0), (1 - share, d1)):
            green = SIG_WALK if d == 0 and d0 + d1 > 0 else min(max(SIG_CYCLE * f, SIG_GREEN_MIN), SIG_GREEN_MAX)
            words.append(int(round(green * 10)))
    # how far each edge is from leaving the map, driving on
    back = defaultdict(list)
    for i, e in enumerate(final):
        for s in e["succ"]:
            back[s].append(i)
    away = [math.inf] * len(final)
    heap = [(plen(e["pts"]) / u, i) for i, e in enumerate(final) if not e["succ"]]
    heapq.heapify(heap)
    while heap:
        d, i = heapq.heappop(heap)
        if d >= away[i]:
            continue
        away[i] = d
        for p in back[i]:
            heapq.heappush(heap, (d + plen(final[p]["pts"]) / u, p))
    hdr[45] = len(words)
    words += [min(AWAY, int(round(d))) if d < math.inf else AWAY for d in away]
    hdr[46] = len(words)
    words += [int(round(e.get("spawn", 1.) * 16)) | (ORPHAN if not e["conn"] and i not in has_in else 0) for i, e in enumerate(final)]
    hdr[39] = len(words)
    words += [0] * (2 * nx * ny)
    hdr[40] = len(words)
    for cy in range(ny):
        for cx in range(nx):
            lst = hcells.get((cx, cy), [])
            o = hdr[39] + 2 * (cy * nx + cx)
            words[o:o + 2] = [len(words) - hdr[40], min(len(lst), SIG_CELL)]
            words += lst[:SIG_CELL]
    words[base:base + HEADER] = hdr
    assert max(words) < (1 << 24), max(words)
    print("%-32s lanes %4d edges %5d entries %3d segs %5d grid %dx%d cars %3d buildings %4d green %3d parked %4d lights %d/%d words %d" % (m["name"], lane_count, len(final), len(entries), len(segs), nx, ny, hdr[22], len(blds), len(grn), len(parks), len(ids), len(heads), len(words)), flush=True)
    return words


def save(blobs):
    words = [len(blobs)] + [0] * len(blobs)
    for k, b in enumerate(blobs):
        words[1 + k] = len(words)
        words += b
    h = (len(words) + W - 1) // W
    a = np.zeros(h * W, np.uint32)
    a[:len(words)] = words
    img = np.stack([(a >> 16) & 255, (a >> 8) & 255, a & 255], -1).astype(np.uint8).reshape(h, W, 3)
    for out in OUT:
        Image.fromarray(img).save(out, optimize=True)
        json.dump([b[22] for b in blobs], open(os.path.splitext(out)[0] + ".json", "w"))
    print("maps.png %dx%d" % (W, h), flush=True)


def labels(font_path):
    """each map's name as a signed distance field strip, LABEL_W x LABEL_H
    a map, in Montserrat SemiBold: left aligned, caps LABEL_CAP of the strip
    tall on its middle, distances in strip heights clamped to +-LABEL_RANGE/2
    and mapped to [0, 255], inside < 0.5"""
    W_, H_ = LABEL_W * LABEL_UP, LABEL_H * LABEL_UP
    probe = ImageFont.truetype(font_path, 1000)
    _, top, _, bot = probe.getbbox("H", anchor="ls")
    font = ImageFont.truetype(font_path, int(round(1000 * LABEL_CAP * H_ / (bot - top))))
    rows = []
    for m in MAPS:
        img = Image.new("L", (W_, H_), 0)
        ImageDraw.Draw(img).text((H_ * 0.1, H_ * (0.5 + LABEL_CAP / 2)), m["name"], font=font, fill=255, anchor="ls")
        a = np.array(img) > 127
        d = distance_transform_edt(~a) - distance_transform_edt(a)
        d = d.reshape(LABEL_H, LABEL_UP, LABEL_W, LABEL_UP).mean(axis=(1, 3)) / H_
        rows.append(np.round((np.clip(d, -LABEL_RANGE / 2, LABEL_RANGE / 2) / LABEL_RANGE + 0.5) * 255).astype(np.uint8))
    for out in LABEL_OUT:
        Image.fromarray(np.concatenate(rows)).save(out, optimize=True)


def main():
    """gen_maps.py <data dir> <font> [words, comma separated]: each
    map's words are kept in the data dir with a hash of this script and
    the map, and only rebuilt when either changed; naming words rebuilds
    the maps whose names hold any of them, the rest coming from whatever
    was kept"""
    data = sys.argv[1]
    os.makedirs(data, exist_ok=True)
    labels(sys.argv[2])
    only = {n.strip() for n in " ".join(sys.argv[3:]).split(",") if n.strip()}
    code = hashlib.sha1(open(__file__, "rb").read()).hexdigest()
    blobs = []
    for m in MAPS:
        key = hashlib.sha1(json.dumps(m, sort_keys=True).encode()).hexdigest()[:16]
        path = os.path.join(data, "blob_%s.json" % key)
        kept = json.load(open(path)) if os.path.exists(path) else None
        if kept and (not any(w in m["name"] for w in only) if only else kept["code"] == code):
            blobs.append(kept["words"])
            print("%-32s kept" % m["name"], flush=True)
            continue
        blobs.append(build(m, data))
        json.dump(dict(code=code, words=blobs[-1]), open(path, "w"))
        save(blobs)
    save(blobs)


main()
