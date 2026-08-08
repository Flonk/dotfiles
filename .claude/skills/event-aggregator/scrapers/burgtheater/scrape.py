import datetime
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

SLUG = "burgtheater"
BASE = "https://www.burgtheater.at"
LIST_URL = BASE + "/spielplan"

VENUE_DISTRICT = {
    "Burgtheater": 1010,
    "Vestibül": 1010,
    "Akademietheater": 1030,
    "Kasino": 1030,
}

BLOCK_RE = re.compile(r'<section  class="s-event s-event.*?</section>', re.S)
DATE_RE = re.compile(r'datetime="(\d{4}-\d{2}-\d{2})"')
TIME_RE = re.compile(r'field--name-start field__item">(\d{2}:\d{2})')
URL_RE = re.compile(r'<a href="(/veranstaltungen/[^"]+)">')
TITLE_RE = re.compile(r'field--name-name field__item">([^<]*)</div>')
VENUE_RE = re.compile(r'field--name-location-room field__item">([^<]*)</div>')
AUTHOR_RE = re.compile(r's-event__author">\s*von\s*([^<]*)</div>', re.S)
CATEGORY_RE = re.compile(r'field--name-event-type field__item s-badge"\s*>([^<]*)</span>')
SUBTITLE_RE = re.compile(r'field--name-subtitle field__item">([^<]*)</div>')


def month_key(d):
    return d.year, d.month


def next_month(y, m):
    return (y + 1, 1) if m == 12 else (y, m + 1)


def parse_month(page):
    out = []
    for block in BLOCK_RE.findall(page):
        dm = DATE_RE.search(block)
        um = URL_RE.search(block)
        tim = TITLE_RE.search(block)
        if not (dm and um and tim):
            continue
        date = dm.group(1)
        tm = TIME_RE.search(block)
        start = f"{date}T{tm.group(1)}" if tm else date
        url = BASE + um.group(1)
        title = ea.text(tim.group(1))
        if not title:
            continue
        vm = VENUE_RE.search(block)
        venue = ea.text(vm.group(1)) if vm else None
        am = AUTHOR_RE.search(block)
        author = ea.text(am.group(1)) if am else None
        cm = CATEGORY_RE.search(block)
        category = ea.text(cm.group(1)) if cm else None
        sm = SUBTITLE_RE.search(block)
        subtitle = ea.text(sm.group(1)) if sm else None
        source_id = um.group(1).split("/veranstaltungen/")[-1].strip("/")
        extra = {}
        if author:
            extra["author"] = author
        out.append({
            "source": SLUG,
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": VENUE_DISTRICT.get(venue),
            "city": "Wien",
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": subtitle,
            "extra": extra,
        })
    return out


def main():
    cutoff = ea.horizon()
    today = datetime.date.today()
    y, m = today.year, today.month
    records = {}
    while True:
        cur = datetime.date(y, m, 1)
        page = ea.fetch(f"{LIST_URL}?date={y:04d}-{m:02d}")
        for r in parse_month(page):
            records[(r["source_id"], r["start"])] = r
        if cur > cutoff:
            break
        y, m = next_month(y, m)
    ea.emit(records.values())


if __name__ == "__main__":
    main()
