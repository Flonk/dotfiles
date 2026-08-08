import re

import ea

BASE = "https://www.moebelmuseumwien.at"
EVENTS_URL = BASE + "/en/program/events"

SPLIT_RE = re.compile(
    r'<div class="teaser-item" itemscope="itemscope" '
    r'itemtype="http://schema\.org/Event">')
DETAIL_HREF_RE = re.compile(
    r'<a class="button primary" title="[^"]*" href="([^"]+)"')

NAME_RE = re.compile(r'itemprop="name" content="([^"]*)"')
DESC_RE = re.compile(r'itemprop="description" content="([^"]*)"')
START_RE = re.compile(r'itemprop="startDate" content="([^"]*)"')
END_RE = re.compile(r'itemprop="endDate" content="([^"]*)"')
ADDR_RE = re.compile(r'itemprop="address"\s*\n?\s*content="([^"]*)"')
TAG_RE = re.compile(r'<div class="tag-box">\s*<span>([^<]*)</span>')
PLACE_RE = re.compile(
    r'icon-place fact-icon.*?<span>\s*([^<]+?)\s*</span>', re.S)
PRICE_RE = re.compile(
    r'icon-price fact-icon.*?<span>\s*([^<]+?)\s*</span>', re.S)


def parse(page):
    records = []
    chunks = SPLIT_RE.split(page)[1:]
    for block in chunks:
        name = NAME_RE.search(block)
        start = START_RE.search(block)
        if not name or not start:
            continue
        href_m = DETAIL_HREF_RE.search(block)
        href = href_m.group(1) if href_m else None
        if not href:
            continue
        title = ea.text(name.group(1))
        start_d = ea.de_date(start.group(1))
        end_m = END_RE.search(block)
        end_d = ea.de_date(end_m.group(1)) if end_m else None
        desc_m = DESC_RE.search(block)
        description = ea.text(desc_m.group(1)) if desc_m else None
        addr_m = ADDR_RE.search(block)
        address = ea.text(addr_m.group(1)) if addr_m else None
        tag_m = TAG_RE.search(block)
        category = ea.text(tag_m.group(1)) if tag_m else None
        place_m = PLACE_RE.search(block)
        venue = ea.text(place_m.group(1)) if place_m else "Möbelmuseum Wien"
        price_m = PRICE_RE.search(block)
        price_min, price_text = ea.price(price_m.group(1)) if price_m else (None, None)
        url = href if href.startswith("http") else BASE + href
        source_id = url.rstrip("/").rsplit("/", 1)[-1]
        records.append({
            "source": "hofmobiliendepot",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start_d,
            "end": end_d,
            "venue": venue,
            "district": ea.district(address) or 1070,
            "city": "Wien",
            "address": address,
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
            "description": description,
        })
    return records


def main():
    page = ea.fetch(EVENTS_URL)
    records = parse(page)
    ea.emit(records)


if __name__ == "__main__":
    main()
