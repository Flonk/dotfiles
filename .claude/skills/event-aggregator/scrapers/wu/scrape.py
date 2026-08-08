import html
import json
import os
import re
import sys
import urllib.error

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

LIST_URL = "https://www.wu.ac.at/universitaet/news-und-events/events"
DETAIL_URL = "https://www.wu.ac.at/?type=9901&tx_news_pi1%5Bnews%5D={id}"
FALLBACK_URL = LIST_URL

ITEM_RE = re.compile(r'<div data-id="(\d+)" class="item">(.*?)(?=<div data-id="|\Z)', re.S)
TITLE_RE = re.compile(r'<h3 class="u__h4">(.*?)</h3>', re.S)
SCHEDULE_RE = re.compile(r'<div class="schedule">.*?</span>(.*?)</div>', re.S)

DATE_RANGE_RE = re.compile(
    r'(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})'
    r'(?:\s*-\s*(?:(\d{2})\.(\d{2})\.(\d{4})\s+)?(\d{2}):(\d{2}))?'
)


def parse_schedule(s):
    if not s:
        return None, None
    m = DATE_RANGE_RE.search(s)
    if not m:
        return None, None
    d1, mo1, y1, h1, mi1, d2, mo2, y2, h2, mi2 = m.groups()
    start = f"{y1}-{mo1}-{d1}T{h1}:{mi1}"
    end = None
    if h2 and mi2:
        if d2 and mo2 and y2:
            end = f"{y2}-{mo2}-{d2}T{h2}:{mi2}"
        else:
            end = f"{y1}-{mo1}-{d1}T{h2}:{mi2}"
    return start, end


def parse_listing(page):
    items = {}
    for m in ITEM_RE.finditer(page):
        id_ = m.group(1)
        if id_ in items:
            continue
        body = m.group(2)
        tm = TITLE_RE.search(body)
        if not tm:
            continue
        title = ea.text(html.unescape(tm.group(1)))
        schedules = SCHEDULE_RE.findall(body)
        schedule_text = schedules[0] if schedules else None
        loc_hint = schedules[1] if len(schedules) > 1 else None
        items[id_] = {"title": title, "schedule": schedule_text, "loc_hint": ea.text(loc_hint)}
    return items


def fetch_detail(id_):
    try:
        raw = ea.fetch(DETAIL_URL.format(id=id_))
    except (urllib.error.URLError, urllib.error.HTTPError):
        return None
    try:
        return json.loads(raw)
    except Exception:
        return None


def pick_url(detail):
    if not detail:
        return None
    for b in detail.get("buttons") or []:
        u = b.get("url") or ""
        if u.startswith("http") and "/ical" not in u:
            return u
    return None


def pick_category(detail):
    if not detail:
        return None
    tags = [t.get("text") for t in (detail.get("tags") or [])
            if not t.get("secondary") and t.get("text")]
    return "; ".join(tags) if tags else None


def main():
    page = ea.fetch(LIST_URL)
    items = parse_listing(page)

    records = []
    for id_, info in items.items():
        start, end = parse_schedule(info["schedule"])
        if not start:
            continue

        detail = fetch_detail(id_)

        url = pick_url(detail) or FALLBACK_URL
        venue = None
        if detail:
            venue = ea.text(detail.get("location"))
        if not venue:
            venue = info["loc_hint"]

        description = None
        if detail:
            description = ea.text(detail.get("subtitle")) or ea.text(detail.get("text"))

        price_min, price_text = (None, None)
        if detail:
            blob = " ".join(filter(None, [detail.get("subtitle"), detail.get("text")]))
            price_min, price_text = ea.price(blob)
            if price_min != 0.0:
                price_min, price_text = None, None

        records.append({
            "source": "wu",
            "source_id": id_,
            "url": url,
            "title": info["title"],
            "start": start,
            "end": end,
            "venue": venue,
            "district": ea.district(venue),
            "city": "Wien",
            "price_min": price_min,
            "price_text": price_text,
            "category": pick_category(detail),
            "description": description,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
