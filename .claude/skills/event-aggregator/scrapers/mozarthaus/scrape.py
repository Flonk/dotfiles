import re
import sys
import urllib.parse

import ea

BASE = "https://www.mozarthausvienna.at"
ADDRESS = "Domgasse 5, 1010 Wien"
VENUE = "Mozarthaus Vienna"
DISTRICT = 1010

CATEGORIES = ["konzert", "event", "workshop", "family-kids", "f%C3%BChrung"]
CATEGORY_LABELS = {
    "konzert": "Konzert",
    "event": "Event",
    "workshop": "Workshop",
    "family-kids": "Family & Kids",
    "f%C3%BChrung": "Führung",
}

CARD_RE = re.compile(
    r'<a href="(/news/[^"]+)">.*?<h2[^>]*>([^<]+)</h2>\s*<div[^>]*>\s*<p>([^<]+)</p>',
    re.S,
)


def fetch_listing(url_base, max_pages=8):
    events = {}
    for p in range(1, max_pages + 1):
        url = url_base if p == 1 else f"{url_base}/p{p}" if "?" not in url_base \
            else url_base.replace("?", f"/p{p}?")
        html = ea.fetch(url)
        found = CARD_RE.findall(html)
        if not found:
            break
        for href, title, when in found:
            events[href] = (ea.text(title), ea.text(when))
        if "Weiter →" not in html:
            break
    return events


def fetch_category_map():
    cat_map = {}
    for cat in CATEGORIES:
        events = fetch_listing(f"{BASE}/events-2?category={cat}")
        for href in events:
            cat_map.setdefault(href, []).append(CATEGORY_LABELS[cat])
    return cat_map


TICKETS_RE = re.compile(
    r'>Tickets</h[14]>.*?<div class="content-text body-neue">\s*(.*?)\s*</div>', re.S)
FIRST_BLOCK_RE = re.compile(
    r'<h4[^>]*>([^<]+)</h4>\s*<div class="flex flex-col gap-8">\s*'
    r'<div class="content-text body-neue">\s*(.*?)\s*</div>', re.S)


def detail_info(url):
    html = ea.fetch(url)
    price_min = price_text = None
    m = TICKETS_RE.search(html)
    if m:
        price_min, price_text = ea.price(m.group(1))
    description = None
    for heading, block in FIRST_BLOCK_RE.findall(html):
        if heading.strip().lower() != "tickets":
            description = ea.text(block)
            break
    return price_min, price_text, description


def main():
    events = fetch_listing(f"{BASE}/events-2")
    cat_map = fetch_category_map()
    cutoff = ea.horizon()

    records = []
    for href, (title, when) in events.items():
        start = ea.de_date(when)
        if not start:
            continue
        start_date = start[:10]
        import datetime
        d = datetime.date.fromisoformat(start_date)
        if d < datetime.date.today():
            continue
        if d > cutoff:
            continue
        url = BASE + urllib.parse.quote(href, safe="/")
        price_min, price_text, description = detail_info(url)
        cats = cat_map.get(href)
        category = ", ".join(cats) if cats else None
        source_id = href.strip("/").split("/")[-1]
        records.append({
            "source": "mozarthaus",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
            "description": description,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
