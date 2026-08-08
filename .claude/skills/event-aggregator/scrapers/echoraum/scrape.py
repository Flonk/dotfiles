import datetime
import re

import ea

LIST_URL = "https://www.echoraum.at/programm/"
VENUE = "echoraum"
ADDRESS = "Sechshauser Straße 66, 1150 Wien"
DISTRICT = 1150

ARTICLE_RE = re.compile(
    r'<article class="post-(\d+)[^"]*\bcategory-programm\b[^"]*">(.*?)</article>',
    re.S,
)
DATUM_RE = re.compile(r'<div class="datum">(.*?)</div>\s*<!-- datum -->', re.S)
H3_RE = re.compile(r'<h3>\s*(?:<a href="([^"]+)"[^>]*>)?(.*?)(?:</a>)?\s*</h3>', re.S)
UNTERTITEL_RE = re.compile(r'<h4 class="untertitel">(.*?)</h4>', re.S)
MITWIRKENDE_RE = re.compile(r'<div class="mitwirkende">(.*?)</div>', re.S)
CATEGORY_RE = re.compile(r'category-([a-z-]+)')
DATE_RE = re.compile(r'(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s*(\d{4})')
TIME_RE = re.compile(r'(\d{1,2}):(\d{2})')

SKIP_CATS = {"programm", "ohne-details"}


def parse_start(raw):
    d = ea.text(raw)
    if not d:
        return None
    dm = DATE_RE.search(d)
    if not dm:
        return None
    day = int(dm.group(1))
    mon = ea.MON.get(dm.group(2)) or ea.MON.get(dm.group(2)[:3])
    year = int(dm.group(3))
    if not mon:
        return None
    tm = TIME_RE.search(d[dm.end():])
    if tm:
        return f"{year:04d}-{mon:02d}-{day:02d}T{int(tm.group(1)):02d}:{tm.group(2)}"
    return f"{year:04d}-{mon:02d}-{day:02d}"


def main():
    page = ea.fetch(LIST_URL)
    cutoff = ea.horizon()
    records = []
    for m in ARTICLE_RE.finditer(page):
        post_id, block = m.group(1), m.group(2)

        h3 = H3_RE.search(block)
        if not h3 or not h3.group(1):
            continue
        url, title = h3.group(1), ea.text(h3.group(2))
        if not title:
            continue

        dm = DATUM_RE.search(block)
        start = parse_start(dm.group(1)) if dm else None
        if not start:
            continue

        start_date = start[:10]
        try:
            if datetime.date.fromisoformat(start_date) > cutoff:
                continue
        except ValueError:
            continue

        cats = [c for c in CATEGORY_RE.findall(block) if c not in SKIP_CATS]
        category = ", ".join(sorted(set(cats))) or None

        parts = []
        um = UNTERTITEL_RE.search(block)
        if um:
            t = ea.text(um.group(1))
            if t:
                parts.append(t)
        mm = MITWIRKENDE_RE.search(block)
        if mm:
            t = ea.text(mm.group(1))
            if t:
                parts.append(t)
        description = " · ".join(parts) or None

        rec = {
            "source": "echoraum",
            "source_id": post_id,
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
            "category": category,
            "description": description,
            "status": "scheduled",
        }
        records.append(rec)

    ea.emit(records)


if __name__ == "__main__":
    main()
