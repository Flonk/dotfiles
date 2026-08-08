import datetime
import json
import urllib.request

import ea

SEARCH_URL = "https://search.wien.gv.at/site_veranstaltungen/_search/template"
SLUG = "wien_gv_at"


def fetch_hits():
    req = urllib.request.Request(
        SEARCH_URL,
        data=json.dumps({
            "id": "search_template_specific",
            "params": {"query_string": "", "filters": [], "from": 0, "size": 1000},
        }).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": "ApiKey ",
            "Origin": "https://www.wien.gv.at",
            "Referer": "https://www.wien.gv.at/veranstaltungen",
            "Accept": "application/json",
            "User-Agent": ea.UA,
        },
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        raw = r.read()
    return json.loads(raw)["hits"]["hits"]


def price_for(src):
    pts = src.get("price_teaser_string") or ""
    p = src.get("price") or {}
    fixed = p.get("fixedPrice")
    if any(t.get("title") == "Gratis" for t in (src.get("defined_terms") or [])):
        return 0.0, pts or "Gratis"
    if isinstance(fixed, (int, float)):
        return float(fixed), pts or None
    pmin, ptext = ea.price(pts)
    return pmin, ptext or (pts or None)


def venue_district(src):
    addr = (src.get("address") or [None])[0]
    if not addr:
        return None, None, None
    parts = [addr.get("addressStreet") or "", addr.get("addressNumber") or ""]
    street = " ".join(p for p in parts if p).strip()
    dist = (addr.get("district") or [None])[0]
    district = None
    if dist and dist.get("plz"):
        try:
            district = int(dist["plz"])
        except ValueError:
            district = None
    return addr.get("addressName") or None, street or None, district


def main():
    hits = fetch_hits()
    cutoff = ea.horizon()
    today = datetime.date.today()
    records = []
    for h in hits:
        src = h["_source"]
        title = src.get("title") or src.get("formated_title")
        url = src.get("link")
        source_id = str(src.get("source_id") or url)
        if not title or not url:
            continue
        venue, street, district = venue_district(src)
        price_min, price_text = price_for(src)
        category = ", ".join(
            t.get("title") for t in (src.get("defined_terms") or []) if t.get("title")
        ) or None
        description = src.get("short_description") or src.get("description")

        de = (src.get("daoh_edit") or {}).get("logic", {})
        sets = de.get("sets") or []
        occs = []
        for s in sets:
            if s.get("type") == "single":
                for dt in s.get("dates") or []:
                    start, end = dt.get("from"), dt.get("to")
                    if not start:
                        continue
                    d = datetime.date.fromisoformat(start[:10])
                    if d < today:
                        continue
                    if d > cutoff:
                        continue
                    occs.append((start, end))
            else:
                for r in s.get("ranges") or []:
                    start, end = r.get("from"), r.get("to")
                    if not start:
                        continue
                    end_d = datetime.date.fromisoformat((end or start)[:10])
                    if end_d < today:
                        continue
                    occs.append((start, end))

        n = len(occs)
        for i, (start, end) in enumerate(occs):
            unknown_time = start.endswith("T00:00:00+02:00") or start.endswith("T00:00:00+01:00")
            if unknown_time and (not end or end[:10] == start[:10]):
                start_v, end_v = start[:10], None
            else:
                start_v = ea.de_date(start) or (start[:16] if "T" in start else start[:10])
                end_v = None
                if end and end != start:
                    end_v = ea.de_date(end) or (end[:16] if "T" in end else end[:10])
            records.append({
                "source": SLUG,
                "source_id": source_id if n == 1 else f"{source_id}-{i}",
                "url": url,
                "title": title,
                "start": start_v,
                "end": end_v,
                "venue": venue,
                "district": district,
                "city": "Wien",
                "address": street,
                "price_min": price_min,
                "price_text": price_text,
                "category": category,
                "description": description,
            })

    ea.emit(records)


if __name__ == "__main__":
    main()
