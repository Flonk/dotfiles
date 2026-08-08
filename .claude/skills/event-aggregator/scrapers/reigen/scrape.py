import json
import sys

import ea

API = "https://www.reigen.at/wp-json/tribe/events/v1/events"
VENUE = "REIGEN LIVE"
ADDRESS = "Hadikgasse 62"
DISTRICT = 1140


def fetch_page(page):
    url = f"{API}?per_page=50&page={page}"
    raw = ea.fetch(url)
    return json.loads(raw)


def to_iso(s):
    if not s:
        return None
    d, t = s.split(" ", 1) if " " in s else (s, "")
    if t and t != "00:00:00":
        return f"{d}T{t[:5]}"
    return d


def build(e):
    start = to_iso(e.get("start_date"))
    if not start:
        return None
    end = to_iso(e.get("end_date"))
    if end and end.split("T")[0] != start.split("T")[0]:
        end = None
    price_min, price_text = ea.price(e.get("cost"))
    desc = ea.text(e.get("description"))
    if desc and len(desc) > 500:
        desc = desc[:500].rsplit(" ", 1)[0] + "…"
    venue = e.get("venue") or {}
    return {
        "source": "reigen",
        "source_id": str(e["id"]),
        "url": e.get("url"),
        "title": ea.text(e.get("title")),
        "start": start,
        "end": None,
        "venue": venue.get("venue") or VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": venue.get("address") or ADDRESS,
        "price_min": price_min,
        "price_text": price_text,
        "category": None,
        "description": desc,
        "status": "scheduled" if e.get("status") != "cancelled" else "cancelled",
    }


def main():
    records = []
    page = 1
    total_pages = 1
    while page <= total_pages and page <= 10:
        try:
            d = fetch_page(page)
        except Exception as ex:
            sys.stderr.write(f"page {page} fetch failed: {ex}\n")
            break
        total_pages = d.get("total_pages", 1)
        events = d.get("events", [])
        if not events:
            break
        for e in events:
            rec = build(e)
            if rec:
                records.append(rec)
        page += 1
    ea.emit(records)


if __name__ == "__main__":
    main()
