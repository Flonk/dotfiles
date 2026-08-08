import datetime
import json
import sys

import ea

API = "https://konzerthaus.at/api/events/"
BASE = "https://konzerthaus.at"
MAIN_VENUE_ADDRESS = "Lothringerstraße 20, 1030 Wien"
MAIN_VENUE_DISTRICT = 1030

STATUS_MAP = {"postponed": "postponed"}


def fetch_page(page, page_size=100):
    today = datetime.date.today().isoformat()
    url = f"{API}?date={today}&page_size={page_size}&page={page}"
    raw = ea.fetch(url)
    return json.loads(raw)


def build(rec):
    eid = rec.get("id")
    slug = (rec.get("slug") or {}).get("de") or str(eid)
    url = f"{BASE}/de/programm-und-karten/{slug}/{eid}"

    start = ea.de_date(rec.get("date_start"))
    if not start:
        return None
    end = ea.de_date(rec.get("date_end"))

    title = ea.text(rec.get("name")) or ""
    pretitle = ea.text(rec.get("pretitle"))
    if pretitle and pretitle not in title:
        title = f"{pretitle}: {title}"
    if not title:
        return None

    genres = [g.get("name") for g in (rec.get("genres") or []) if g.get("name")]
    category = ", ".join(genres) if genres else None

    prices = rec.get("prices") or []
    vals = []
    for p in prices:
        try:
            vals.append(float(p.get("price")))
        except (TypeError, ValueError):
            pass
    price_min = min(vals) if vals else None
    price_text = f"ab € {price_min:.2f}" if price_min is not None else None

    room = rec.get("room") or {}
    venue_obj = room.get("venue") or {}
    venue_name = venue_obj.get("name")
    room_name = room.get("name")
    district = None
    address = None
    if venue_name == "externe Veranstaltungsstätten":
        venue = room_name or venue_name
    else:
        venue = f"Wiener Konzerthaus – {room_name}" if room_name else "Wiener Konzerthaus"
        district = MAIN_VENUE_DISTRICT
        address = MAIN_VENUE_ADDRESS

    status = STATUS_MAP.get(rec.get("status"), "scheduled")

    subtitle = ea.text(rec.get("subtitle"))
    description = ea.text(rec.get("description_short")) or subtitle

    return {
        "source": "konzerthaus",
        "source_id": str(eid),
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
        "status": status,
    }


def main():
    cutoff = ea.horizon().isoformat()
    records = []
    page = 1
    seen = set()
    while True:
        data = fetch_page(page)
        results = data.get("results") or []
        if not results:
            break
        stop = False
        for rec in results:
            ds = rec.get("date_start")
            if ds and ds[:10] > cutoff:
                stop = True
                break
            eid = rec.get("id")
            if eid in seen:
                continue
            seen.add(eid)
            r = build(rec)
            if r:
                records.append(r)
        if stop or not data.get("next"):
            break
        page += 1
        if page > 100:
            break
    ea.emit(records)


if __name__ == "__main__":
    main()
