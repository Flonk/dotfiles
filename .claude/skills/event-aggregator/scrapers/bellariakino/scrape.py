import datetime
import zoneinfo

import ea

API = "https://api.cineamo.com/showings"
CINEMA_ID = "3000"
VENUE = "Bellaria Kino"
ADDRESS = "Museumstraße 3, 1070 Wien"
DISTRICT = 1070
VIENNA = zoneinfo.ZoneInfo("Europe/Vienna")


def local_dt(iso_utc):
    if not iso_utc:
        return None
    dt = datetime.datetime.strptime(iso_utc, "%Y-%m-%dT%H:%M:%SZ")
    dt = dt.replace(tzinfo=datetime.timezone.utc).astimezone(VIENNA)
    return dt.strftime("%Y-%m-%dT%H:%M")


def fetch_all():
    import json
    items = []
    page = 1
    while True:
        url = f"{API}?cinemaIds%5B0%5D={CINEMA_ID}&perPage=100&page={page}"
        raw = ea.fetch(url)
        data = json.loads(raw)
        batch = data.get("_embedded", {}).get("showings", [])
        items.extend(batch)
        if page >= data.get("_page_count", page):
            break
        page += 1
    return items


def lang_desc(it):
    parts = []
    lang = it.get("language")
    if lang:
        parts.append(f"OV: {lang}")
    if it.get("isDubbed") and it.get("dubbedLanguage"):
        parts.append(f"synchronisiert: {it['dubbedLanguage']}")
    if it.get("isSubtitled") and it.get("subtitledLanguage"):
        parts.append(f"UT: {it['subtitledLanguage']}")
    return ", ".join(parts) if parts else None


def build(it):
    start = local_dt(it.get("startDatetime"))
    if not start:
        return None
    title = ea.text(it.get("name"))
    if not title:
        return None
    content = (it.get("_embedded") or {}).get("content") or {}
    content_id = it.get("contentId")
    showing_id = it.get("id")
    url = f"https://www.bellariakino.at/de/programm/{content_id}/{showing_id}"
    desc_parts = [p for p in (ea.text(content.get("description")), lang_desc(it)) if p]
    return {
        "source": "bellariakino",
        "source_id": str(showing_id),
        "url": url,
        "title": title,
        "start": start,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": content.get("category"),
        "description": " / ".join(desc_parts) if desc_parts else None,
        "status": "scheduled" if it.get("state") != "cancelled" else "cancelled",
    }


def main():
    today = datetime.date.today()
    cutoff = ea.horizon()
    items = fetch_all()
    records = []
    for it in items:
        rec = build(it)
        if not rec:
            continue
        d = datetime.date.fromisoformat(rec["start"][:10])
        if d < today or d > cutoff:
            continue
        records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
