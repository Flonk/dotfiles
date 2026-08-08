import html
import re
import sys

import ea

BASE = "https://neueoperwien.at/programm/"
SLUG = "neueoperwien"


def slugify(s):
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s


def main():
    page = ea.fetch(BASE)
    idx = page.find("<body")
    body = page[idx:] if idx != -1 else page

    items = re.findall(
        r'<li class="fusion-layout-column.*?post-card.*?</li>', body, re.S)

    records = []
    for it in items:
        m = re.search(
            r'<h2[^>]*><a href="([^"]+)"[^>]*>([^<]+)</a></h2>', it)
        if not m:
            continue
        url, title = m.group(1), html.unescape(m.group(2)).strip()

        ps = re.findall(r"<p>(.*?)</p>", it, re.S)
        ps = [html.unescape(re.sub(r"<[^>]+>", " ", x)).strip() for x in ps]
        ps = [p for p in ps if p]

        subtitle = None
        time_str = None
        date_rows = []
        for p in ps:
            dm = re.match(r"(\d{2})\.(\d{2})\.(\d{2})\b", p)
            if dm:
                day, mon, yr = dm.groups()
                venue = p[dm.end():]
                venue = re.sub(r"^\s*\d{4}\s*", "", venue)
                venue = venue.lstrip("–- ").strip()
                premiere = "premiere" in venue.lower()
                venue = re.sub(r"\s*\(premiere\)\s*$", "", venue, flags=re.I).strip()
                date_rows.append((day, mon, yr, venue, premiere))
            elif p.lower().startswith("beginn"):
                tm = re.search(r"(\d{1,2}):(\d{2})", p)
                if tm:
                    time_str = f"{int(tm.group(1)):02d}:{tm.group(2)}"
            elif subtitle is None and not date_rows:
                subtitle = p

        if not date_rows:
            continue

        for day, mon, yr, venue, premiere in date_rows:
            year = 2000 + int(yr)
            start = f"{year:04d}-{int(mon):02d}-{int(day):02d}"
            if time_str:
                start += f"T{time_str}"
            sid = f"{slugify(title)}-{year:04d}{int(mon):02d}{int(day):02d}"
            extra = {}
            if subtitle:
                extra["subtitle"] = subtitle
            if premiere:
                extra["premiere"] = True
            records.append({
                "source": SLUG,
                "source_id": sid,
                "url": url,
                "title": title,
                "start": start,
                "end": None,
                "venue": venue or None,
                "district": ea.district(venue),
                "city": "Wien",
                "address": None,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": subtitle,
                "status": "scheduled",
                "extra": extra or None,
            })

    ea.emit(records)


if __name__ == "__main__":
    main()
