import json
import sys

import ea

API = "https://filmfestival-rathausplatz.at/wp-json/tribe/events/v1/events"


def genre_of(ev):
    for v in (ev.get("custom_fields") or {}).values():
        label = (v.get("label") or "").strip()
        if label.startswith("Genre"):
            return v.get("value")
    return None


def main():
    horizon = ea.horizon().isoformat()
    records = []
    page = 1
    while True:
        url = f"{API}?per_page=50&page={page}"
        raw = ea.fetch(url)
        try:
            data = json.loads(raw)
        except Exception as e:
            sys.stderr.write(f"{url}: bad json ({e})\n")
            break
        events = data.get("events") or []
        if not events:
            break
        for ev in events:
            start = (ev.get("start_date") or "").replace(" ", "T")[:16]
            end = (ev.get("end_date") or "").replace(" ", "T")[:16] or None
            if not start:
                continue
            if start[:10] > horizon:
                continue
            records.append({
                "source": "rathausplatz",
                "source_id": str(ev["id"]),
                "url": ev.get("url"),
                "title": ev.get("title"),
                "start": start,
                "end": end,
                "venue": "Rathausplatz",
                "district": 1010,
                "city": "Wien",
                "address": "Rathausplatz, 1010 Wien",
                "price_min": 0.0,
                "price_text": "Eintritt frei",
                "category": genre_of(ev),
                "description": ea.text(ev.get("description")),
                "status": "scheduled",
            })
        total_pages = data.get("total_pages") or 1
        if page >= total_pages:
            break
        page += 1

    ea.emit(records)


if __name__ == "__main__":
    main()
