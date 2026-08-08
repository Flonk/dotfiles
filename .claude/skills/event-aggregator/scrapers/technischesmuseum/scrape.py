import datetime
import json
import re

import ea

BASE = "https://www.technischesmuseum.at"
LIST_URL = f"{BASE}/ausstellungen"

SLUG = "technischesmuseum"


def jsonld_lenient(page):
    out = []
    for m in re.finditer(
            r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
            page, re.S | re.I):
        try:
            d = json.loads(m.group(1).strip(), strict=False)
        except Exception:
            continue
        stack = [d]
        while stack:
            n = stack.pop()
            if isinstance(n, list):
                stack.extend(n)
            elif isinstance(n, dict):
                out.append(n)
                stack.extend(v for v in n.values() if isinstance(v, (list, dict)))
    return out


def kategorie_map(listing):
    m = {}
    for match in re.finditer(
            r'href="/ausstellung/([a-zA-Z0-9_-]+)">.*?<div class="kategorie">(.*?)</div>',
            listing, re.S):
        slug, label = match.group(1), re.sub(r"\s+", " ", match.group(2)).strip()
        m.setdefault(slug, label)
    return m


def main():
    listing = ea.fetch(LIST_URL)
    slugs = sorted(set(re.findall(r'href="/ausstellung/([a-zA-Z0-9_-]+)"', listing)))
    kategorien = kategorie_map(listing)

    records = []
    for slug in slugs:
        url = f"{BASE}/ausstellung/{slug}"
        try:
            page = ea.fetch(url)
        except Exception:
            continue
        exhib = None
        for d in jsonld_lenient(page):
            if d.get("@type") == "ExhibitionEvent":
                exhib = d
                break
        if not exhib:
            continue

        start = ea.de_date(exhib.get("startDate"))
        end = ea.de_date(exhib.get("endDate")) if exhib.get("endDate") else None
        if not start:
            continue

        description = ea.text(ea.text(exhib.get("description")))
        kategorie = kategorien.get(slug, "")
        permanent = ("dauerhaft" in kategorie.lower()
                     or (description and "Dauerausstellung" in description))
        if permanent:
            end = None
        elif end:
            today = datetime.date.today().isoformat()
            if end[:10] < today:
                continue

        loc = exhib.get("location") or {}
        addr = loc.get("address") or {}
        street = addr.get("streetAddress")
        postal = addr.get("postalCode")
        locality = addr.get("addressLocality")
        address = ", ".join(p for p in [street, f"{postal} {locality}".strip()] if p) or None

        rec = {
            "source": SLUG,
            "source_id": slug,
            "url": exhib.get("url") or url,
            "title": exhib.get("name"),
            "start": start,
            "end": end,
            "venue": loc.get("name"),
            "district": ea.district(postal),
            "city": "Wien",
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": description,
        }
        if permanent:
            rec["extra"] = {"permanent": True}
        records.append(rec)

    ea.emit(records)


if __name__ == "__main__":
    main()
