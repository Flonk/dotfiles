import json
import os
import re
import sys
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://arena.wien"
API = BASE + "/DesktopModules/WebAPI/API/Event/Search"
ADDRESS = "Baumgasse 80, 1030 Wien"
DISTRICT = 1030


def fetch_list():
    q = urllib.parse.urlencode({
        "searchTerm": "",
        "day": 1,
        "month": -1,
        "year": -1,
        "page": 0,
        "pageSize": 10000,
        "eventCategory": -1,
        "abonnement": -1,
        "cultureCode": "de-AT",
        "locationId": 0,
    })
    raw = ea.fetch(f"{API}?{q}")
    data = json.loads(raw)
    return data.get("concerts") or []


def main():
    cutoff = ea.horizon().isoformat()
    concerts = fetch_list()
    records = []
    for c in concerts:
        begin = c.get("DateBegin")
        if not begin:
            continue
        start_date = begin[:10]
        if start_date > cutoff:
            continue
        start = begin[:16] if len(begin) >= 16 else begin[:10]
        if start.endswith("T00:00"):
            start = start[:10]
        detail_m = re.search(r"concert-id/(\d+)", c.get("DetailUrl") or "")
        cid = detail_m.group(1) if detail_m else (c.get("DetailUrl") or c.get("Title"))
        url = c.get("DetailUrl") or BASE
        end = None
        if c.get("DateEnd"):
            end_raw = c["DateEnd"]
            end = end_raw[:16] if len(end_raw) >= 16 else end_raw[:10]
            if end.endswith("T00:00"):
                end = end[:10]
        title = ea.text(c.get("Title")) or c.get("Title")
        if not title:
            continue
        venue = ea.text(c.get("Location")) or "Arena Wien"
        records.append({
            "source": "arena",
            "source_id": str(cid),
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": None,
            "extra": {"subtitle": ea.text(c.get("Subtitle"))} if c.get("Subtitle") else None,
        })
    ea.emit(records)


if __name__ == "__main__":
    main()
