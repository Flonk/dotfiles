import datetime
import html
import re

import ea

URL = "https://www.belvedere.at/ausstellungen"

VENUE_DISTRICT = {
    "Oberes Belvedere": 1030,
    "Unteres Belvedere": 1030,
    "Belvedere 21": 1030,
}

ROW_RE = re.compile(r'<article data-history-node-id="(\d+)"[^>]*>(.*?)</article>', re.S)
CAT_RE = re.compile(r'content__header__element">\s*([^<]+?)\s*</span>')
VENUE_RE = re.compile(r'content__header__element">\s*<span>([^<]*)</span>\s*</div>')
TITLE_RE = re.compile(r'<h3[^>]*>\s*<span>([^<]*)</span>')
SUB_RE = re.compile(
    r'text-black text-size-16 small slate[^"]*">\s*<span>\s*<span>([^<]*)</span>', re.S)
TIME_RE = re.compile(r'<time datetime="([^"]+)">')
LINK_RE = re.compile(r'link--full" href="([^"]+)"')


def main():
    page = ea.fetch(URL)

    recs = []
    for m in ROW_RE.finditer(page):
        source_id, block = m.group(1), m.group(2)

        cat_m = CAT_RE.search(block)
        category = html.unescape(cat_m.group(1)).strip() if cat_m else None

        venue_m = VENUE_RE.search(block)
        venue = html.unescape(venue_m.group(1)).strip() if venue_m else None

        title_m = TITLE_RE.search(block)
        title = html.unescape(title_m.group(1)).strip() if title_m else None
        if not title:
            continue

        sub_m = SUB_RE.search(block)
        subtitle = html.unescape(sub_m.group(1)).strip() if sub_m else None
        description = subtitle or None

        times = TIME_RE.findall(block)
        times = sorted(set(times))

        link_m = LINK_RE.search(block)
        path = link_m.group(1) if link_m else None
        url = f"https://www.belvedere.at{path}" if path and path.startswith("/") else (path or URL)

        permanent = False
        if len(times) >= 2:
            start = times[0][:10]
            end = times[1][:10]
        elif len(times) == 1:
            start = times[0][:10]
            end = None
            permanent = True
        else:
            start = datetime.date.today().isoformat()
            end = None
            permanent = True

        if end and end < datetime.date.today().isoformat():
            continue

        rec = {
            "source": "belvedere",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": VENUE_DISTRICT.get(venue),
            "city": "Wien",
            "address": None,
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": description,
            "status": "scheduled",
        }
        if permanent:
            rec["extra"] = {"permanent": True}
        recs.append(rec)

    ea.emit(recs)


if __name__ == "__main__":
    main()
