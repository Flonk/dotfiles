import html
import re
import sys

import ea

LIST_URL = "https://www.porgy.at/events/upcoming"
BASE = "https://www.porgy.at"
VENUE = "Porgy & Bess"
ADDRESS = "Riemergasse 11, 1010 Wien"
DISTRICT = 1010

ROW_RE = re.compile(r'<div class="row event_list[^"]*"\s*>')
DATE_RE = re.compile(r'<div class="date">([^<]*)</div>')
TIME_RE = re.compile(r'<div class="time">([^<]*)</div>')
STAGE_RE = re.compile(r'<a href="/events/stage/\d+/">([^<]*)</a>')
ZYKLUS_RE = re.compile(r'<div class="zyklus"[^>]*>\s*(.*?)</div>', re.S)
SERIES_RE = re.compile(r'<span class="series"\s*>\s*(.*?)</span>', re.S)
TITLE_RE = re.compile(r'<div class="title"\s*>\s*<a href="(/events/(\d+)/)">(.*?)</a>', re.S)


def parse_rows(page):
    blocks = ROW_RE.split(page)[1:]
    last_date = None
    rows = []
    for b in blocks:
        m = DATE_RE.search(b)
        if m:
            last_date = ea.text(m.group(1))
        tm = TIME_RE.search(b)
        time_s = ea.text(tm.group(1)) if tm else None
        stage_m = STAGE_RE.search(b)
        stage = ea.text(stage_m.group(1)) if stage_m else None
        cat = None
        zm = ZYKLUS_RE.search(b)
        if zm:
            cat = ea.text(zm.group(1))
        else:
            sm = SERIES_RE.search(b)
            if sm:
                cat = ea.text(sm.group(1))
        tm2 = TITLE_RE.search(b)
        if not tm2 or not last_date:
            continue
        href, eid, title_raw = tm2.group(1), tm2.group(2), tm2.group(3)
        title = ea.text(title_raw)
        if not title:
            continue
        rows.append({
            "eid": eid,
            "url": BASE + href,
            "title": title,
            "date": last_date,
            "time": time_s,
            "stage": stage,
            "category": cat,
        })
    return rows


def fetch_price(url):
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"detail fetch failed {url}: {e}\n")
        return None, None
    m = re.search(r'<div class="tickets">(.*?)</div>', page, re.S)
    block = m.group(1) if m else page
    block = re.sub(r'<!--.*?-->', '', block, flags=re.S)
    return ea.price(block)


def build(row):
    start = ea.de_date(f"{row['date']} {row['time']}" if row["time"] else row["date"])
    if not start:
        return None
    price_min, price_text = fetch_price(row["url"])
    venue = VENUE if not row["stage"] else f"{VENUE} – {row['stage']}"
    return {
        "source": "porgy",
        "source_id": row["eid"],
        "url": row["url"],
        "title": row["title"],
        "start": start,
        "end": None,
        "venue": venue,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": price_min,
        "price_text": price_text,
        "category": row["category"],
        "description": None,
        "status": "scheduled",
    }


def main():
    page = ea.fetch(LIST_URL)
    rows = parse_rows(page)
    records = []
    for row in rows:
        rec = build(row)
        if rec:
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
