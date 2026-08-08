import datetime
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://www.vienna-events.com"
LIST_URL = BASE + "/en/events"


def parse_page(html):
    mats = re.findall(
        r'<script[^>]+type="application/ld\+json"[^>]*>(.*?)</script>', html, re.S)
    links = re.findall(r'href="(/en//events/[^"]+)"', html)
    total = None
    m = re.search(r"<h2>(\d+)<!-- --> <!-- -->Events found</h2>", html)
    if m:
        total = int(m.group(1))
    return mats, links, total


def main():
    horizon = ea.horizon()
    today = datetime.date.today()
    records = []
    seen = set()
    page = 1
    while True:
        cache = None
        url = LIST_URL if page == 1 else f"{LIST_URL}?page={page}"
        html = ea.fetch(url, cache=cache)
        mats, links, total = parse_page(html)
        if not mats:
            break
        n_total_pages = None
        if total:
            n_total_pages = (total + len(mats) - 1) // len(mats) if mats else None

        import json
        page_max_date = None
        for raw, link in zip(mats, links):
            try:
                d = json.loads(raw)
            except Exception:
                continue
            if d.get("@type") != "Event":
                continue
            name = d.get("name")
            start_raw = d.get("startDate")
            end_raw = d.get("endDate") or start_raw
            start = (ea.de_date(start_raw) or "")[:10] or None
            end = (ea.de_date(end_raw) or "")[:10] if end_raw else None
            if not name or not start:
                continue
            name = re.sub(r"\s+", " ", name).strip()
            sd = start[:10]
            try:
                start_date_obj = datetime.date.fromisoformat(sd)
            except ValueError:
                start_date_obj = None
            if start_date_obj and start_date_obj < today:
                continue
            if page_max_date is None or (start_date_obj and start_date_obj > page_max_date):
                page_max_date = start_date_obj

            detail_url = BASE + link.replace("/en//events/", "/en/events/")
            m = re.search(r"-e(\d+)$", link)
            source_id = m.group(1) if m else detail_url

            loc = d.get("location") or {}
            venue = loc.get("name")

            keywords = d.get("keywords") or ""
            category = d.get("eventCategory") or (keywords.split(",")[0].strip() if keywords else None)

            if (source_id, start) in seen:
                continue
            seen.add((source_id, start))

            records.append({
                "source": "vienna_events",
                "source_id": source_id,
                "url": detail_url,
                "title": name.strip(),
                "start": start,
                "end": end if end and end != start else None,
                "venue": venue,
                "district": ea.district(venue),
                "city": "Wien",
                "address": None,
                "price_min": None,
                "price_text": None,
                "category": category,
                "description": None,
                "extra": {"keywords": keywords} if keywords else {},
            })

        if page_max_date and page_max_date > horizon:
            break
        if n_total_pages and page >= n_total_pages:
            break
        if not n_total_pages and len(mats) < 20:
            break
        page += 1
        if page > 60:
            break

    ea.emit(records)


if __name__ == "__main__":
    main()
