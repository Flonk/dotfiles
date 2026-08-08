import datetime
import re

import ea

BASE = "https://www.josephinum.ac.at"
EVENTS_URL = BASE + "/veranstaltungen/"
EXHIBITIONS_URL = BASE + "/aktuelle-ausstellungen/"

VENUE = "Josephinum"
ADDRESS = "Währinger Straße 25, 1090 Wien"
DISTRICT = 1090

DATE_RE = re.compile(r'<span class="date">\s*(\d{2}\.\d{2}\.\d{4})\s*</span>', re.S)
TIME_RE = re.compile(r'<span class="time">\s*([\d:]+)\s*-\s*([\d:]+)\s*UHR\s*</span>', re.S)
HREF_RE = re.compile(r'<a class="stretched-link" href="([^"]+)"')
TITLE_RE = re.compile(r'<div class="h4 event-title">\s*<a[^>]*>(.*?)</a>', re.S)
DESC_RE = re.compile(r'<div class="text ellipse two-lines">(.*?)<a ', re.S)


def slug_from_url(url):
    return url.rstrip("/").rsplit("/", 1)[-1]


def fetch_month(ym, cache_dir=None):
    url = f"{EVENTS_URL}?ed={ym}"
    return ea.fetch(url)


def parse_events(cutoff):
    today = datetime.date.today()
    year, month = today.year, today.month
    recs = {}
    seen_empty_streak = 0
    for _ in range(24):
        ym = f"{year:04d}-{month:02d}"
        page = fetch_month(ym)
        blocks = page.split('<div class="event-item">')[1:]
        if not blocks:
            seen_empty_streak += 1
        else:
            seen_empty_streak = 0
        for block in blocks:
            dm = DATE_RE.search(block)
            hm = HREF_RE.search(block)
            tm = TITLE_RE.search(block)
            if not (dm and hm and tm):
                continue
            day, mo, yr = dm.group(1).split(".")
            start = f"{yr}-{mo}-{day}"
            tmm = TIME_RE.search(block)
            if tmm:
                start = f"{start}T{tmm.group(1)}"
            url = BASE + hm.group(1)
            title = ea.text(tm.group(1))
            if not title:
                continue
            dscm = DESC_RE.search(block)
            description = ea.text(dscm.group(1)) if dscm else None
            source_id = slug_from_url(hm.group(1))
            recs[source_id] = {
                "source": "josephinum",
                "source_id": source_id,
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
                "category": None,
                "description": description,
                "status": "scheduled",
            }
        month += 1
        if month > 12:
            month = 1
            year += 1
        if f"{year:04d}-{month:02d}-01" > cutoff.isoformat():
            break
    return list(recs.values())


SLIDE_SPLIT = '<div class="swiper-slide slide-item event-item">'
SLIDE_HREF_RE = re.compile(r'class="stretched-link"[^>]*href="([^"]+)"')
SLIDE_DATE_RE = re.compile(r'<span class="date">([^<]*)</span>')
SLIDE_TITLE_RE = re.compile(r'<div class="title h4"><span>(.*?)</span></div>', re.S)
SLIDE_DESC_RE = re.compile(r'<div class="text ellipse two-lines">(.*?)<a class="stretched-link"', re.S)


def parse_exhibitions(today):
    page = ea.fetch(EXHIBITIONS_URL)
    recs = []
    for block in page.split(SLIDE_SPLIT)[1:]:
        hm = SLIDE_HREF_RE.search(block)
        tm = SLIDE_TITLE_RE.search(block)
        if not (hm and tm):
            continue
        title = ea.text(tm.group(1))
        if not title:
            continue
        url = BASE + hm.group(1)
        source_id = slug_from_url(hm.group(1))

        dm = SLIDE_DATE_RE.search(block)
        start, end, permanent = None, None, False
        if dm:
            raw = dm.group(1).strip()
            if " - " in raw:
                s_raw, e_raw = [p.strip() for p in raw.split(" - ", 1)]
                start = ea.de_date(s_raw)
                if e_raw.lower() == "tbd":
                    end = None
                    permanent = True
                else:
                    end = ea.de_date(e_raw)
            else:
                start = ea.de_date(raw)
        else:
            permanent = True

        if not start:
            start = today.isoformat() if permanent else None
        if not start:
            continue

        if end and end < today.isoformat():
            continue

        dscm = SLIDE_DESC_RE.search(block)
        description = ea.text(dscm.group(1)) if dscm else None

        rec = {
            "source": "josephinum",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": "Ausstellung",
            "description": description,
            "status": "scheduled",
        }
        if permanent:
            rec["extra"] = {"permanent": True}
        recs.append(rec)
    return recs


def main():
    cutoff = ea.horizon()
    today = datetime.date.today()
    recs = parse_events(cutoff)
    recs += parse_exhibitions(today)
    ea.emit(recs)


if __name__ == "__main__":
    main()
