import json
import re
import sys

import ea

LIST_URL = "https://www.eventbrite.at/d/austria--wien/all-events/"
SERVER_DATA_RE = re.compile(r"window\.__SERVER_DATA__ = (\{.*?\});\s*\n", re.S)
MAX_PAGES = 55


def fetch_page(n):
    url = f"{LIST_URL}?page={n}"
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"fetch failed page={n}: {e}\n")
        return None
    m = SERVER_DATA_RE.search(page)
    if not m:
        return None
    try:
        d = json.loads(m.group(1))
    except Exception as e:
        sys.stderr.write(f"json parse failed page={n}: {e}\n")
        return None
    return d.get("search_data", {}).get("events", {})


def build(r):
    eid = str(r.get("id") or r.get("eid") or "")
    url = r.get("url")
    title = ea.text(r.get("name"))
    if not eid or not url or not title:
        return None

    start_date, start_time = r.get("start_date"), r.get("start_time")
    if not start_date:
        return None
    start = f"{start_date}T{start_time}" if start_time else start_date

    end_date, end_time = r.get("end_date"), r.get("end_time")
    end = None
    if end_date:
        end = f"{end_date}T{end_time}" if end_time else end_date
        if end == start:
            end = None

    venue_obj = r.get("primary_venue") or {}
    venue = venue_obj.get("name")
    address_obj = venue_obj.get("address") or {}
    address = address_obj.get("localized_address_display")
    city = address_obj.get("city")
    district = None
    pc = address_obj.get("postal_code")
    if pc and pc.isdigit() and 1010 <= int(pc) <= 1230:
        district = int(pc)

    category = None
    for tag in (r.get("tags") or []):
        if tag.get("prefix") == "EventbriteCategory":
            category = tag.get("display_name")
            break

    status = "cancelled" if r.get("is_cancelled") else "scheduled"

    return {
        "source": "eventbrite",
        "source_id": eid,
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": district,
        "city": city,
        "address": address,
        "price_min": None,
        "price_text": None,
        "category": category,
        "description": ea.text(r.get("summary")),
        "status": status,
    }


def main():
    seen = {}
    page = 1
    while page <= MAX_PAGES:
        events = fetch_page(page)
        if events is None:
            break
        results = events.get("results") or []
        if not results:
            break
        for r in results:
            eid = str(r.get("id") or r.get("eid") or "")
            if eid and eid not in seen:
                seen[eid] = r
        pagination = events.get("pagination") or {}
        if not pagination.get("continuation"):
            break
        page += 1

    records = []
    for r in seen.values():
        rec = build(r)
        if rec:
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
