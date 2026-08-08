import html
import re

import ea

URL = "https://www.hgm.at/events"

VENUE_INFO = {
    "HGM": ("Heeresgeschichtliches Museum", "Arsenal 1, 1030 Wien", 1030, "Wien"),
    "Panzerhalle": ("Panzerhalle (HGM)", "Arsenal 1, 1030 Wien", 1030, "Wien"),
    "Heldenplatz": ("Heldenplatz", None, 1010, "Wien"),
    "Korneuburg": ("Korneuburg", None, None, "Korneuburg"),
}

CARD_SPLIT = re.compile(r'<div class="col-12 col-md-6 col-lg-4 mb-3">')
DETAIL_RE = re.compile(r'href="(/events/details/[^"]+)"')
VENUE_RE = re.compile(
    r'<a class="badge bg-secondary-20 text-black" href="/events">\s*([^<]+?)\s*</a>', re.S)
PRICE_RE = re.compile(
    r'<span class="badge bg-secondary-20 text-black">\s*([^<]+?)\s*</span>', re.S)
DATE_RE = re.compile(r'(\d{2})\s*/\s*(\d{2})\s*/\s*(\d{4})')
TIME_RE = re.compile(r'(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})\s*Uhr')
TITLE_RE = re.compile(
    r'<h3 class="card-title">\s*<a href="[^"]+">\s*([^<]+?)\s*</a>', re.S)
DESC_RE = re.compile(
    r'<div class="card-text">\s*<p class="mt-2">\s*([^<]*?)\s*</p>', re.S)


def parse_price(text):
    if not text:
        return None, None
    if re.search(r"kostenfrei|gratis|kostenlos", text, re.I):
        return 0.0, text
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*(?:Euro|EUR|€)", text, re.I)
    if m:
        return float(m.group(1).replace(",", ".")), text
    return None, text


def main():
    page = ea.fetch(URL)
    cutoff = ea.horizon().isoformat()

    recs = []
    for block in CARD_SPLIT.split(page)[1:]:
        dm = DETAIL_RE.search(block)
        if not dm:
            continue
        path = dm.group(1)
        source_id = path.rsplit("/", 1)[-1]
        url = "https://www.hgm.at" + path

        tm = TITLE_RE.search(block)
        title = html.unescape(tm.group(1)).strip() if tm else None
        if not title:
            continue

        vm = VENUE_RE.search(block)
        venue_raw = html.unescape(vm.group(1)).strip() if vm else None
        venue, address, district, city = VENUE_INFO.get(
            venue_raw, (venue_raw, None, None, "Wien"))

        pm = PRICE_RE.search(block)
        price_text = html.unescape(pm.group(1)).strip() if pm else None
        price_min, price_text = parse_price(price_text)

        dmatch = DATE_RE.search(block)
        if not dmatch:
            continue
        day, month, year = dmatch.groups()
        start = f"{year}-{month}-{day}"

        tmatch = TIME_RE.search(block)
        if tmatch:
            start = f"{start}T{tmatch.group(1)}"

        if start[:10] > cutoff:
            continue

        dscm = DESC_RE.search(block)
        description = html.unescape(dscm.group(1)).strip() if dscm else None

        recs.append({
            "source": "hgm",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": district,
            "city": city,
            "address": address,
            "price_min": price_min,
            "price_text": price_text,
            "category": None,
            "description": description,
            "status": "scheduled",
        })

    ea.emit(recs)


if __name__ == "__main__":
    main()
