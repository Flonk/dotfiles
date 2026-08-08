import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://www.schoenbrunn.at"
LISTING = BASE + "/veranstaltungen/alle-veranstaltungen"

TEASER_RE = re.compile(
    r'<div class="teaser-item"[^>]*itemtype="http://schema.org/Event">(.*?)'
    r'class="fact-list-container"',
    re.S)
URL_RE = re.compile(r'itemprop="url" content="(https://www\.schoenbrunn\.at/veranstaltungen/[^"]+)"')
NAME_RE = re.compile(r'<h3>(.*?)</h3>', re.S)
TAG_RE = re.compile(r'<div class="tag-box">\s*<span>(.*?)</span>', re.S)

FACT_LIST_RE = re.compile(r'class="fact-list-container">(.*?)</div></div></div></div></section>', re.S)
DATE_FACT_RE = re.compile(
    r'icon-events fact-icon.*?<span class="date">\s*(.*?)\s*</span>', re.S)
PLACE_FACT_RE = re.compile(
    r'icon-place fact-icon.*?<span>\s*(.*?)\s*</span>', re.S)
PRICE_FACT_RE = re.compile(
    r'icon-price fact-icon.*?<span>\s*(.*?)\s*</span>', re.S)
DESC_RE = re.compile(r'<meta name="description" content="([^"]*)"')
H1_DESC_RE = re.compile(r'<div class="content-area narrow">\s*<h2>.*?</h2>\s*<p>\s*(.*?)\s*</p>', re.S)


def parse_date_span(s):
    s = ea.text(s) or ""
    parts = [p.strip() for p in s.split(" - ") if p.strip()]
    if not parts:
        return None, None
    start = ea.de_date(parts[0])
    end = ea.de_date(parts[1]) if len(parts) > 1 else None
    return start, end


def main():
    page = ea.fetch(LISTING)

    items = []
    for m in TEASER_RE.finditer(page):
        block = m.group(1)
        um = URL_RE.search(block)
        nm = NAME_RE.search(block)
        tm = TAG_RE.search(block)
        if not (um and nm):
            continue
        url = um.group(1)
        detail_url = url.replace(
            "/veranstaltungen/alle-veranstaltungen/",
            "/veranstaltungen/alle-veranstaltungen/event/")
        items.append({
            "url": detail_url,
            "title": ea.text(nm.group(1)),
            "category": ea.text(tm.group(1)) if tm else None,
        })

    records = []
    for it in items:
        source_id = it["url"].rstrip("/").rsplit("/", 1)[-1]
        try:
            dpage = ea.fetch(it["url"])
        except Exception as e:
            sys.stderr.write(f"skip {it['url']}: {e}\n")
            continue

        fl = FACT_LIST_RE.search(dpage)
        fact_block = fl.group(1) if fl else dpage

        dm = DATE_FACT_RE.search(fact_block)
        start, end = parse_date_span(dm.group(1)) if dm else (None, None)
        if not start:
            continue

        pm = PLACE_FACT_RE.search(fact_block)
        venue = ea.text(pm.group(1)) if pm else None

        prm = PRICE_FACT_RE.search(fact_block)
        price_text = ea.text(prm.group(1)) if prm else None
        price_min = None
        if price_text and re.search(r"\bfrei\b|\bgratis\b|kostenlos", price_text, re.I):
            price_min = 0.0

        desc_m = DESC_RE.search(dpage)
        description = ea.text(desc_m.group(1)) if desc_m else None
        long_desc = H1_DESC_RE.search(dpage)
        if long_desc:
            description = ea.text(long_desc.group(1)) or description

        records.append({
            "source": "schoenbrunn",
            "source_id": source_id,
            "url": it["url"],
            "title": it["title"],
            "start": start,
            "end": end,
            "venue": venue,
            "district": 1130,
            "city": "Wien",
            "price_min": price_min,
            "price_text": price_text,
            "category": it["category"],
            "description": description,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
