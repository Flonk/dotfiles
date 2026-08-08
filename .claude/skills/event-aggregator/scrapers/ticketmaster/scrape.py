import re
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://www.ticketmaster.at/discover/wien"
STATUS_MAP = {
    "https://schema.org/EventCancelled": "cancelled",
    "https://schema.org/EventPostponed": "postponed",
    "https://schema.org/EventRescheduled": "postponed",
}


def source_id(url):
    m = re.search(r"/(\d+)(?:\?.*)?$", url)
    return m.group(1) if m else url


def main():
    horizon = ea.horizon()
    records = []
    for page in range(1, 21):
        url = BASE if page == 1 else f"{BASE}?page={page}"
        try:
            html = ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"fetch failed page {page}: {e}\n")
            break
        events = [n for n in ea.jsonld(html) if n.get("@type") == "Event"]
        if not events:
            break
        for e in events:
            start_raw = e.get("startDate")
            start = ea.de_date(start_raw)
            if not start:
                continue
            loc = e.get("location") or {}
            addr = loc.get("address") or {}
            venue = loc.get("name")
            postal = addr.get("postalCode")
            dist = None
            if postal and re.match(r"^1\d{3}$", postal):
                dist = int(postal)
            street = addr.get("streetAddress")
            status = STATUS_MAP.get(e.get("eventStatus"), "scheduled")
            records.append({
                "source": "ticketmaster",
                "source_id": source_id(e.get("url") or ""),
                "url": e.get("url"),
                "title": e.get("name"),
                "start": start,
                "end": None,
                "venue": venue,
                "district": dist,
                "city": addr.get("addressLocality") or "Wien",
                "address": street,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": e.get("description"),
                "status": status,
            })
        last_start = events[-1].get("startDate")
        if last_start:
            import datetime
            try:
                d = datetime.date.fromisoformat(last_start[:10])
                if d > horizon:
                    break
            except ValueError:
                pass
    ea.emit(records)


if __name__ == "__main__":
    main()
