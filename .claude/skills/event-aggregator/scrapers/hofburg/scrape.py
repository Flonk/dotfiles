import re

import ea

URL = "https://www.hofburg-wien.at/fuehrungen/termine"
BASE = "https://www.sisimuseum-hofburg.at"

MARKER = '<div class="teaser-item" itemscope="itemscope" itemtype="http://schema.org/Event">'

TITLE_RE = re.compile(r'<meta itemprop="name" content="([^"]+)"/>\s*\n?\s*<meta itemprop="description"')
DESC_RE = re.compile(r'<meta itemprop="description" content="([^"]*)"')
START_RE = re.compile(r'<meta itemprop="startDate" content="([^"]+)"')
END_RE = re.compile(r'<meta itemprop="endDate" content="([^"]+)"')
ADDR_RE = re.compile(r'<meta itemprop="address"\s*\n?\s*content="([^"]+)"')
LOCNAME_RE = re.compile(r'itemtype="https://schema.org/Place">.*?<meta itemprop="name"\s*\n?\s*content="([^"]*)"', re.S)
EVENTURL_RE = re.compile(r'<meta itemprop="url" content="([^"]+)"/>\s*\n*\s*<div class="teaser-item-inner"')
CATEGORY_RE = re.compile(r'<div class="tag-box">\s*<span>([^<]+)</span>')
PRICE_RE = re.compile(r'icon-price fact-icon.*?<span>\s*(.*?)\s*</span>\s*</span>', re.S)


def main():
    page = ea.fetch(URL, headers={"Accept-Language": "de-AT,de;q=0.9"})

    recs = []
    for chunk in page.split(MARKER)[1:]:
        block = chunk[:6000]

        title_m = TITLE_RE.search(block)
        title = title_m.group(1).strip() if title_m else None
        if not title:
            continue

        desc_m = DESC_RE.search(block)
        description = ea.text(desc_m.group(1)) if desc_m else None

        start_m = START_RE.search(block)
        end_m = END_RE.search(block)
        if not start_m:
            continue
        start = start_m.group(1)
        end = end_m.group(1) if end_m else None

        url_m = EVENTURL_RE.search(block)
        url = url_m.group(1) if url_m else URL
        source_id = url.rstrip("/").rsplit("/", 1)[-1]

        addr_m = ADDR_RE.search(block)
        address = ea.text(addr_m.group(1)) if addr_m else None
        district = ea.district(address)

        loc_m = LOCNAME_RE.search(block)
        venue = ea.text(loc_m.group(1)) if loc_m else None

        cat_m = CATEGORY_RE.search(block)
        category = ea.text(cat_m.group(1)) if cat_m else None

        price_m = PRICE_RE.search(block)
        price_min, price_text = ea.price(price_m.group(1)) if price_m else (None, None)

        recs.append({
            "source": "hofburg",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": district,
            "city": "Wien",
            "address": address,
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
            "description": description,
            "status": "scheduled",
        })

    ea.emit(recs)


if __name__ == "__main__":
    main()
