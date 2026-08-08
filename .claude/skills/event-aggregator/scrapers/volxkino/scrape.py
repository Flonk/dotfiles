import datetime
import json
import re
import sys
import zoneinfo

import ea

BASE = "https://www.volxkino.at"
VIENNA = zoneinfo.ZoneInfo("Europe/Vienna")


def to_local(iso):
    if not iso:
        return None
    dt = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
    dt = dt.astimezone(VIENNA)
    return dt.strftime("%Y-%m-%dT%H:%M")


def find_events(page):
    m = re.search(
        r'<script[^>]+id="wix-warmup-data"[^>]*>(.*?)</script>', page, re.S)
    if not m:
        return []
    data = json.loads(m.group(1))
    out = []
    apps = data.get("appsWarmupData") or {}
    for app in apps.values():
        for widget in app.values():
            if not isinstance(widget, dict):
                continue
            ev = widget.get("events")
            if isinstance(ev, dict) and isinstance(ev.get("events"), list):
                out.extend(ev["events"])
    return out


def main():
    page = ea.fetch(BASE + "/", cache="page.html")
    events = find_events(page)
    cutoff = ea.horizon()
    records = []
    for e in events:
        eid = e.get("id")
        slug = e.get("slug")
        title = e.get("title")
        if not title or not eid:
            continue
        sched = (e.get("scheduling") or {}).get("config") or {}
        start = to_local(sched.get("startDate"))
        if not start:
            continue
        start_date = datetime.date.fromisoformat(start[:10])
        if start_date > cutoff:
            continue
        end = to_local(sched.get("endDate"))
        loc = e.get("location") or {}
        address = loc.get("address")
        venue = loc.get("name") or (address.split(",")[0].strip() if address else None)
        desc = ea.text(e.get("description"))
        records.append({
            "source": "volxkino",
            "source_id": eid,
            "url": f"{BASE}/event-details/{slug}" if slug else f"{BASE}/",
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": ea.district(address),
            "city": "Wien",
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": desc,
        })
    ea.emit(records)


if __name__ == "__main__":
    main()
