import datetime
import json
import re
import time

import ea

SLUG = "meetup_wien"
URL = "https://www.meetup.com/cities/at/vienna/"

NEXT_DATA_RE = re.compile(
    r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', re.S)


def fetch_retry(url, timeout=30, tries=5, deadline_s=90):
    delay = 1.5
    deadline = time.time() + deadline_s
    last = None
    for _ in range(tries):
        try:
            return ea.fetch(url, timeout=timeout)
        except Exception as e:
            last = e
            if time.time() > deadline:
                break
            time.sleep(delay)
            delay *= 2
    raise last


def collect_events(page_props):
    seen = {}
    for v in page_props.values():
        if isinstance(v, list) and v and isinstance(v[0], dict) and v[0].get("__typename") == "Event":
            for e in v:
                eid = e.get("id")
                if eid:
                    seen[eid] = e
    return list(seen.values())


def local_dt(s):
    if not s:
        return None
    m = re.match(r"(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})", s)
    return f"{m.group(1)}T{m.group(2)}" if m else None


def main():
    raw = fetch_retry(URL)
    m = NEXT_DATA_RE.search(raw)
    if not m:
        ea.emit([])
        return
    data = json.loads(m.group(1))
    page_props = data.get("props", {}).get("pageProps", {}) or {}
    events = collect_events(page_props)

    today = datetime.date.today()
    cutoff = ea.horizon()

    records = []
    for e in events:
        title = e.get("title")
        url = e.get("eventUrl")
        eid = e.get("id")
        start = local_dt(e.get("dateTime"))
        if not (title and url and eid and start):
            continue
        try:
            d = datetime.date.fromisoformat(start[:10])
        except ValueError:
            continue
        if d < today or d > cutoff:
            continue

        end = local_dt(e.get("endTime"))
        if end and end[:10] != start[:10] and end <= start:
            end = None
        if end == start:
            end = None

        venue = e.get("venue") or {}
        venue_name = venue.get("name") or None
        address = venue.get("address") or None
        city = venue.get("city") or None
        district = ea.district(address) if address else None
        if district is None and city:
            district = ea.district(city)
        if city:
            plz_prefix = re.match(r"^\d{4}\s+(.+)", city.strip())
            if plz_prefix:
                city = plz_prefix.group(1).strip() or None
            elif city.strip().isdigit():
                city = None

        fee = e.get("feeSettings") or {}
        price_min = fee.get("amount")
        price_text = None
        if price_min is not None:
            price_text = f"{price_min} {fee.get('currency') or ''}".strip()
            price_min = float(price_min)

        image = None
        photo = e.get("featuredEventPhoto") or {}
        hi = photo.get("highResUrl")
        if hi and "fallback" not in hi:
            image = hi

        records.append({
            "source": SLUG,
            "source_id": str(eid),
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": venue_name,
            "district": district,
            "city": city,
            "address": address,
            "price_min": price_min,
            "price_text": price_text,
            "category": None,
            "image": image,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
