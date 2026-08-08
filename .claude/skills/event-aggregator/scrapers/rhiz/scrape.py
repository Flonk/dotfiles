import datetime
import json
import re

import ea

API = "https://rhiz.wien/wp-json/copilot-promotion/v1/promotions"
VENUE_ADDRESS = "U-Bahnbogen 37, 1080 Wien"
VENUE_DISTRICT = 1080

ISO_RE = re.compile(r"(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})")

STATUS_MAP = {
    "scheduled": "scheduled",
    "cancelled": "cancelled",
    "canceled": "cancelled",
    "postponed": "postponed",
}


def iso_to_local(s):
    if not s:
        return None
    m = ISO_RE.search(s)
    if not m:
        return None
    return f"{m.group(1)}T{m.group(2)}"


def main():
    page = ea.fetch(API)
    data = json.loads(page)
    cutoff = ea.horizon()

    records = []
    for r in data.get("data", []):
        raw_str = r.get("rawEvent")
        raw = json.loads(raw_str) if raw_str else {}

        title = (r.get("title") or "").strip()
        if not title:
            continue

        start = iso_to_local(r.get("start"))
        if not start:
            continue

        start_date = datetime.date.fromisoformat(start[:10])
        if start_date > cutoff:
            continue

        end_field = raw.get("end")
        end_iso = None
        if end_field and isinstance(end_field, dict):
            end_iso = iso_to_local((end_field.get("value") or {}).get("dateTimeISO"))

        slug = r.get("slug") or r.get("id")
        url = f"https://rhiz.wien/?copilot-slug={slug}"

        desc_field = raw.get("description")
        description = None
        if desc_field and isinstance(desc_field, dict):
            html = (desc_field.get("value") or {}).get("html")
            description = ea.text(html)

        subtitle_field = raw.get("subtitle")
        subtitle = None
        if subtitle_field and isinstance(subtitle_field, dict):
            subtitle = (subtitle_field.get("value") or {}).get("label") or None

        status_field = raw.get("status")
        status = "scheduled"
        if status_field and isinstance(status_field, dict):
            s = (status_field.get("value") or {}).get("status")
            status = STATUS_MAP.get((s or "").lower(), "scheduled")

        presale_field = raw.get("presaleLink")
        presale_href = None
        if presale_field and isinstance(presale_field, dict):
            presale_href = (presale_field.get("value") or {}).get("href") or None

        category = r.get("category") or None

        extra = {}
        if subtitle:
            extra["subtitle"] = subtitle
        if presale_href:
            extra["ticket_url"] = presale_href

        records.append({
            "source": "rhiz",
            "source_id": str(r.get("id") or slug),
            "url": url,
            "title": title,
            "start": start,
            "end": end_iso,
            "venue": r.get("venueName") or "rhiz",
            "district": VENUE_DISTRICT,
            "city": "Wien",
            "address": VENUE_ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": description,
            "status": status,
            "extra": extra or None,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
