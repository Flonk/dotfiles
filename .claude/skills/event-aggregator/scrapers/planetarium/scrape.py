import datetime
import re

import ea

BASE = "https://www.vhs.at/de/e/planetarium/veranstaltungen"
LIST_URL = (BASE + "?_semc=planetarium&sp.sort=sem_event_start+asc%2Cbegzeit+asc"
            "&f.sem_grouping=sem_grouping%3Akurs&q=*&f.showcourses=buchbare"
            "&group.offset={offset}")

DISTRICT = {
    "Planetarium": 1020,
    "Urania Sternwarte": 1010,
    "Kuffner Sternwarte": 1160,
}
ADDRESS = {
    "Planetarium": "Oswald-Thomas-Platz 1",
    "Urania Sternwarte": "Uraniastraße 1",
    "Kuffner Sternwarte": "Johann-Staud-Straße 10",
}

ARTICLE_RE = re.compile(
    r'<article\s+class="courseOverviewItem[^"]*courseOverviewItem--([a-z0-9-]*)[^"]*"'
    r'\s+id="k(\d+)">(.*?)</article>', re.S)
TITLE_RE = re.compile(r'courseOverviewItem__title"><a href="([^"]+)">([^<]+)</a>')
SUBTITLE_RE = re.compile(r'courseOverviewItem__subtitle">([^<]*)</p>')
PRICE_RE = re.compile(r'courseOverviewItem__price">\s*([\d,]+)\s*&euro;')
LOC_RE = re.compile(r'icon-marker.*?</span>\s*(?:<a[^>]*>)?\s*([^<\n]+?)\s*(?:</a>)?\s*</td>', re.S)
DATE_RE = re.compile(
    r'Termin[e]?,\s*(\d{2}\.\d{2}\.\d{4})\s*<br>\s*[A-Za-zÄÖÜäöü]+,?\s*'
    r'(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})\s*Uhr', re.S)
CATEGORY_LABEL = {
    "naturwissenschaften-und-technik": "Naturwissenschaften und Technik",
    "science": "Science",
}


def parse_page(html):
    out = []
    for cat_slug, cid, block in ARTICLE_RE.findall(html):
        t = TITLE_RE.search(block)
        if not t:
            continue
        title = ea.text(t.group(2))
        sub = SUBTITLE_RE.search(block)
        subtitle = ea.text(sub.group(1)) if sub and sub.group(1).strip() else None
        if subtitle:
            title = f"{title} {subtitle}"
        price_m = PRICE_RE.search(block)
        price_min = None
        price_text = None
        if price_m:
            val = float(price_m.group(1).replace(",", "."))
            price_min = val
            price_text = f"€ {price_m.group(1)}"
        loc_m = LOC_RE.search(block)
        venue = ea.text(loc_m.group(1)) if loc_m else None
        date_m = DATE_RE.search(block)
        category = CATEGORY_LABEL.get(cat_slug, cat_slug or None)
        if not date_m:
            continue
        d, m, y = date_m.group(1).split(".")
        start = f"{y}-{m}-{d}T{date_m.group(2)}"
        end = f"{y}-{m}-{d}T{date_m.group(3)}"
        out.append({
            "source": "planetarium",
            "source_id": cid,
            "url": f"https://www.vhs.at{t.group(1)}",
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": DISTRICT.get(venue),
            "city": "Wien",
            "address": ADDRESS.get(venue),
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
        })
    return out


def main():
    cutoff = ea.horizon()
    offset = 0
    seen = set()
    records = []
    empty_streak = 0
    while offset < 2000:
        html = ea.fetch(LIST_URL.format(offset=offset))
        page_records = parse_page(html)
        if not page_records:
            empty_streak += 1
            if empty_streak >= 2:
                break
        else:
            empty_streak = 0
        new_any = False
        past_cutoff = False
        for r in page_records:
            if r["source_id"] in seen:
                continue
            seen.add(r["source_id"])
            new_any = True
            start_date = datetime.date.fromisoformat(r["start"][:10])
            if start_date > cutoff:
                past_cutoff = True
                continue
            records.append(r)
        if past_cutoff:
            break
        if not new_any and page_records:
            break
        offset += 10
    ea.emit(records)


if __name__ == "__main__":
    main()
