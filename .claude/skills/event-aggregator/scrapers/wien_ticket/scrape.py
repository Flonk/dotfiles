import base64
import datetime
import json
import re

import ea

BASE = "https://www.wien-ticket.at"
CATEGORIES = ["konzerte", "klassik", "kultur", "musicals-shows", "sport", "freizeit"]
PER_PAGE = 20
MAX_PAGES = 40

LI_RE = re.compile(
    r'<li class="event-list-item[^"]*"\s+data-tracking="([^"]+)">(.*?)</li>', re.S)
HREF_RE = re.compile(r'<a href="([^"]+)"')
INFO_RE = re.compile(r'info-btn m0">\s*([^<]+?)\s*</p>', re.S)
TITLE_RE = re.compile(r'<h2[^>]*>(.*?)</h2>', re.S)
LOC_RE = re.compile(r'event-location[^"]*"[^>]*>([^<]+)</p>', re.S)
PRICE_RE = re.compile(r'data-alternativetext="([^"]*)"')
COUNT_RE = re.compile(r'(\d+)\s*Events')
DATE2_RE = re.compile(r'(\d{2})\.(\d{2})\.(\d{4})')


def page_url(cat, page):
    if page == 1:
        return f"{BASE}/de/{cat}/catalog"
    return f"{BASE}/de/{cat}/catalog/from{1 + PER_PAGE * (page - 1)}"


def parse_start(item):
    d = item.get("veranstaltungsdatum")
    t = item.get("veranstaltungszeit")
    m = re.match(r"(\d{2})\.(\d{2})\.(\d{4})", d or "")
    if not m:
        return None
    dd, mm, yy = m.groups()
    date_s = f"{yy}-{mm}-{dd}"
    if t and re.match(r"^\d{2}:\d{2}$", t):
        return f"{date_s}T{t}"
    return date_s


def parse_end(info_text, start_date):
    if not info_text:
        return None
    dates = DATE2_RE.findall(info_text)
    if len(dates) < 2:
        return None
    dd, mm, yy = dates[1]
    end_date = f"{yy}-{mm}-{dd}"
    if end_date == start_date[:10]:
        return None
    return end_date


def main():
    horizon = ea.horizon()
    today = datetime.date.today()
    seen = set()
    records = []
    for cat in CATEGORIES:
        page = 1
        total_pages = MAX_PAGES
        keep_going = True
        while page <= total_pages and page <= MAX_PAGES and keep_going:
            url = page_url(cat, page)
            html_doc = ea.fetch(url)
            if page == 1:
                cm = COUNT_RE.search(html_doc)
                if cm:
                    n = int(cm.group(1))
                    total_pages = max(1, -(-n // PER_PAGE))
            lis = list(LI_RE.finditer(html_doc))
            if not lis:
                break
            page_exceeded = False
            for m in lis:
                b64, body = m.groups()
                try:
                    tracking = json.loads(base64.b64decode(b64))
                    item = tracking["ecommerce"]["items"][0]
                except Exception:
                    continue
                href_m = HREF_RE.search(body)
                if not href_m:
                    continue
                detail_url = BASE + href_m.group(1)
                source_id = str(item.get("item_id") or href_m.group(1))
                if source_id in seen:
                    continue
                title_m = TITLE_RE.search(body)
                title = ea.text(title_m.group(1)) if title_m else ea.text(item.get("item_name"))
                if not title:
                    continue
                loc_m = LOC_RE.search(body)
                venue, city = None, None
                if loc_m:
                    loc = ea.text(loc_m.group(1))
                    if loc:
                        parts = [p.strip() for p in loc.rsplit(",", 1)]
                        if len(parts) == 2:
                            venue, city = parts
                        else:
                            venue = loc
                if not venue:
                    venue = ea.text(item.get("spielstaette"))
                price_m = PRICE_RE.search(body)
                price_min, price_text = ea.price(price_m.group(1)) if price_m else (None, None)

                start = parse_start(item)
                start_date = None
                if start:
                    try:
                        start_date = datetime.date.fromisoformat(start[:10])
                    except ValueError:
                        start_date = None

                if not start_date or start_date < today:
                    seen.add(source_id)
                    records.append({
                        "source": "wien_ticket",
                        "source_id": source_id,
                        "url": detail_url,
                        "title": title,
                        "start": today.isoformat(),
                        "end": None,
                        "venue": venue,
                        "district": None,
                        "city": city,
                        "price_min": price_min,
                        "price_text": price_text,
                        "category": item.get("item_category"),
                        "extra": {"permanent": True},
                    })
                    continue

                if start_date > horizon:
                    page_exceeded = True
                    continue

                seen.add(source_id)
                info_m = INFO_RE.search(body)
                end = parse_end(info_m.group(1) if info_m else None, start)
                records.append({
                    "source": "wien_ticket",
                    "source_id": source_id,
                    "url": detail_url,
                    "title": title,
                    "start": start,
                    "end": end,
                    "venue": venue,
                    "district": None,
                    "city": city,
                    "price_min": price_min,
                    "price_text": price_text,
                    "category": item.get("item_category"),
                })
            if page_exceeded:
                keep_going = False
            page += 1
    ea.emit(records)


if __name__ == "__main__":
    main()
