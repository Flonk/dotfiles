import datetime
import re

import ea

URL = "https://breitenseer-lichtspiele.at/"
VENUE = "Breitenseer Lichtspiele"
ADDRESS = "Breitenseer Straße 21, 1140 Wien"
DISTRICT = 1140

ITEM_RE = re.compile(
    r'<a href="(https://breitenseer-lichtspiele\.at/event/[^"]+)"'
    r' title="[^"]*" class="grid justify-center grid-cols-6.*?</a>',
    re.S,
)
DATE_RE = re.compile(r'tracking-wider">\s*([^<]+?)\s*</span>')
TITLE_RE = re.compile(r'font-bold pt-2">\s*(.*?)\s*</span>', re.S)
DESC_RE = re.compile(r'<div class="prose prose-slate mt-4">(.*?)</div>', re.S)

WEEKDAY_MONTH_RE = re.compile(
    r'[A-Za-zÄÖÜäöü]{2},\s*(\d{2})\.(\d{2})\.(\d{4})\s*\|\s*(\d{2}):(\d{2})'
)

SKIP_TITLES = ("sommerpause", "geschlossen")


def build(m):
    url = m.group(1)
    block = m.group(0)

    dm = DATE_RE.search(block)
    tm = TITLE_RE.search(block)
    if not dm or not tm:
        return None

    title = ea.text(tm.group(1))
    if not title:
        return None
    if any(s in title.lower() for s in SKIP_TITLES):
        return None

    wm = WEEKDAY_MONTH_RE.search(dm.group(1))
    if not wm:
        return None
    day, mon, year, hh, mm = wm.groups()
    start = f"{year}-{mon}-{day}T{hh}:{mm}"

    dsc_m = DESC_RE.search(block)
    description = ea.text(dsc_m.group(1)) if dsc_m else None

    slug = url.rstrip("/").rsplit("/", 1)[-1]

    return {
        "source": "breitenseer",
        "source_id": slug,
        "url": url,
        "title": title,
        "start": start,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": None,
        "description": description,
        "status": "scheduled",
    }


def main():
    page = ea.fetch(URL, cache=None)
    cutoff = ea.horizon()
    records = []
    for m in ITEM_RE.finditer(page):
        rec = build(m)
        if not rec:
            continue
        y, mo, d = (int(x) for x in rec["start"][:10].split("-"))
        if datetime.date(y, mo, d) > cutoff:
            continue
        records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
