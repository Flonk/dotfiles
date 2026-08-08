import datetime
import json
import sys

import ea

API = "https://www.depot.or.at/wp-json/tribe/events/v1/events"
VENUE = "Depot"
DISTRICT = 1070
ADDRESS = "Breite Gasse 3, 1070 Wien"


def to_iso(s):
    if not s:
        return None
    d, t = s.split(" ")
    if t == "00:00:00":
        return d
    return f"{d}T{t[:5]}"


def main():
    cutoff = ea.horizon()
    records = []
    page = 1
    total_pages = 1
    while page <= total_pages and page <= 10:
        url = f"{API}?per_page=50&page={page}"
        raw = ea.fetch(url)
        data = json.loads(raw)
        total_pages = data.get("total_pages") or 1
        for e in data.get("events", []):
            start = to_iso(e.get("start_date"))
            if not start:
                continue
            start_date = datetime.date.fromisoformat(start[:10])
            if start_date > cutoff:
                continue
            end = to_iso(e.get("end_date"))
            cats = [c.get("name") for c in (e.get("categories") or []) if c.get("name")]
            category = ", ".join(cats) if cats else None
            records.append({
                "source": "depot",
                "source_id": str(e["id"]),
                "url": e.get("url"),
                "title": e.get("title"),
                "start": start,
                "end": end,
                "venue": VENUE,
                "district": DISTRICT,
                "city": "Wien",
                "address": ADDRESS,
                "price_min": 0,
                "price_text": "Eintritt frei",
                "category": category,
                "description": ea.text(e.get("description")),
                "extra": {"depot_id": e["id"]},
            })
        page += 1

    ea.emit(records)


if __name__ == "__main__":
    main()
