import datetime
import json

import ea

WP = "https://cms.skrapid.at/wp-json/wp/v2"
SCHEDULE_URL = "https://www.skrapid.at/teams/spielplan"


def fetch_all(path, fields):
    out = []
    page = 1
    while True:
        url = f"{WP}/{path}?per_page=100&page={page}&_fields={fields}"
        try:
            raw = ea.fetch(url)
        except Exception:
            break
        data = json.loads(raw)
        if not data:
            break
        out.extend(data)
        if len(data) < 100:
            break
        page += 1
    return out


def main():
    comps = {str(c["id"]): c["title"]["rendered"] for c in fetch_all("competition", "id,title")}
    matches = fetch_all("match", "id,title,meta")

    today = datetime.date.today()
    cutoff = ea.horizon()

    records = []
    for m in matches:
        meta = m.get("meta") or {}
        date_s = meta.get("sk_match_date")
        title = (m.get("title") or {}).get("rendered")
        if not date_s or not title:
            continue
        try:
            d = datetime.date.fromisoformat(date_s)
        except ValueError:
            continue
        if d < today or d > cutoff:
            continue

        time_s = meta.get("sk_match_time") or ""
        start = date_s
        if time_s and time_s != "00:00:00":
            hm = time_s[:5]
            if len(hm) == 5 and hm[2] == ":":
                start = f"{date_s}T{hm}"

        status = "cancelled" if meta.get("sk_match_status") == "Cancelled" else "scheduled"
        comp_id = meta.get("sk_match_competition") or ""
        category = comps.get(comp_id, comp_id or None)
        venue = meta.get("sk_match_venue") or None
        matchday = meta.get("sk_match_matchday") or None
        ticket_link = meta.get("sk_match_ticket_link") or None
        venue_city = meta.get("sk_match_venue_city") or None

        extra = {}
        if matchday:
            extra["matchday"] = matchday
        if ticket_link:
            extra["ticket_link"] = ticket_link
        if venue_city:
            extra["venue_city"] = venue_city

        records.append({
            "source": "skrapid",
            "source_id": str(m["id"]),
            "url": SCHEDULE_URL,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": None,
            "city": "Wien",
            "address": None,
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": None,
            "status": status,
            "extra": extra or None,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
