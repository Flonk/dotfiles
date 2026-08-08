import datetime
import re
import sys

import ea

LIST_URL = "https://grelleforelle.com/programm"
VENUE = "Grelle Forelle"

ITEM_RE = re.compile(
    r'<div id="post-(\d+)" class="([^"]*)">.*?'
    r'<a href="(https://www\.grelleforelle\.com/project/[^"]+)">.*?'
    r'<h2><a href="[^"]+">(.*?)</a></h2>',
    re.S)

TITLE_DATE_RE = re.compile(r'^\s*(\d{2})/(\d{2})\s+(.*)$', re.S)
DOORS_RE = re.compile(r'DOORS\s*<br\s*/?>\s*(\d{1,2})[:.](\d{2})', re.I)


def parse_list(page):
    rows = []
    for post_id, classes, url, title_raw in ITEM_RE.findall(page):
        title = ea.text(title_raw)
        if not title:
            continue
        ym = re.search(r'project_category_(20\d\d)\b', classes)
        year = int(ym.group(1)) if ym else None
        cat = None
        cm = re.search(r'project_category-(club|live)\b', classes)
        if cm:
            cat = cm.group(1)
        rows.append({
            "id": post_id,
            "url": url,
            "title": title,
            "year": year,
            "category": cat,
        })
    return rows


def door_time(url):
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"detail fetch failed {url}: {e}\n")
        return None
    m = DOORS_RE.search(page)
    if not m:
        return None
    return f"{int(m.group(1)):02d}:{m.group(2)}"


def build(row):
    m = TITLE_DATE_RE.match(row["title"])
    if not m or not row["year"]:
        return None
    day, month, rest_title = m.group(1), m.group(2), m.group(3).strip()
    start_date = f"{row['year']:04d}-{month}-{day}"
    try:
        datetime.date.fromisoformat(start_date)
    except ValueError:
        return None
    time_s = door_time(row["url"])
    start = f"{start_date}T{time_s}" if time_s else start_date
    return {
        "source": "grelleforelle",
        "source_id": row["id"],
        "url": row["url"],
        "title": rest_title or row["title"],
        "start": start,
        "end": None,
        "venue": VENUE,
        "district": None,
        "city": "Wien",
        "address": None,
        "price_min": None,
        "price_text": None,
        "category": row["category"],
        "description": None,
        "status": "scheduled",
    }


def main():
    page = ea.fetch(LIST_URL)
    rows = parse_list(page)
    today = datetime.date.today()
    records = []
    for row in rows:
        rec = build(row)
        if not rec:
            continue
        start_date = rec["start"][:10]
        if datetime.date.fromisoformat(start_date) < today:
            continue
        records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
