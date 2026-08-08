import datetime
import html
import re
import sys

import ea

BASE = "https://www.sargfabrik.at"
LIST_URL = f"{BASE}/veranstaltungen"
VENUE_BASE = "Sargfabrik"
ADDRESS = "Goldschlagstraße 169, 1140 Wien"
DISTRICT = 1140

MONTH_OPT_RE = re.compile(r'<option value="(\d{4}-\d{2})"[^>]*>')
BLOCK_DATE_RE = re.compile(
    r'font-typewriter align-top">\d+</div>\s*<p class="italic">\s*[A-Za-zÄÖÜäöü]{2}\.\s*'
    r'(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]{3})\s*</p>')
TIME_RE = re.compile(r'italic flex flex-wrap items-center">\s*(\d{1,2}:\d{2})')
TITLE_RE = re.compile(r'<a class="title" href="(/veranstaltungen/[^"]+)">([^<]*)</a>')
SUBTITLE_RE = re.compile(r'<a class="subtitle"[^>]*>\s*([^<]*?)\s*</a>')
TAGS_RE = re.compile(
    r'class="italic md:text-lg">\s*<span class="font-bold">\s*([^<]*?)\s*</span>,\s*'
    r'<span>\s*([^<]*?)\s*</span>', re.S)


def month_options(page):
    return MONTH_OPT_RE.findall(page)


def parse_month(page, ym):
    year = int(ym.split("-")[0])
    s = re.sub(r"<picture>.*?</picture>", "", page, flags=re.S)
    s = re.sub(r"<svg.*?</svg>", "", s, flags=re.S)
    blocks = s.split("event-calendar-item")[1:]
    rows = []
    for b in blocks:
        dm = BLOCK_DATE_RE.search(b)
        tm = TIME_RE.search(b)
        title_m = TITLE_RE.search(b)
        if not (dm and title_m):
            continue
        day, mon_abbr = dm.groups()
        month = ea.MON.get(mon_abbr) or ea.MON.get(mon_abbr.capitalize())
        if not month:
            continue
        date = f"{year:04d}-{month:02d}-{int(day):02d}"
        time_s = tm.group(1) if tm else None
        start = f"{date}T{time_s}" if time_s else date
        href, title_raw = title_m.groups()
        title = ea.text(html.unescape(title_raw))
        if not title:
            continue
        sub_m = SUBTITLE_RE.search(b)
        subtitle = ea.text(html.unescape(sub_m.group(1))) if sub_m else None
        tags_m = TAGS_RE.search(b)
        area, cats = (None, None)
        if tags_m:
            area = ea.text(html.unescape(tags_m.group(1)))
            cats = ea.text(html.unescape(tags_m.group(2)))
        rows.append({
            "url": BASE + href,
            "source_id": href.rsplit("/", 1)[-1],
            "title": title,
            "start": start,
            "subtitle": subtitle,
            "area": area,
            "category": cats,
        })
    return rows


PRICE_BLOCK_RE = re.compile(
    r'<div class="bard__module text mb-8">\s*(.*?)\s*</div>', re.S)


def fetch_price(url):
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"detail fetch failed {url}: {e}\n")
        return None, None
    m = PRICE_BLOCK_RE.search(page)
    if not m:
        return None, None
    block = ea.text(m.group(1))
    return ea.price(block)


def build(row):
    price_min, price_text = fetch_price(row["url"])
    venue = f"{VENUE_BASE} – {row['area']}" if row["area"] else VENUE_BASE
    return {
        "source": "sargfabrik",
        "source_id": row["source_id"],
        "url": row["url"],
        "title": row["title"],
        "start": row["start"],
        "end": None,
        "venue": venue,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": price_min,
        "price_text": price_text,
        "category": row["category"],
        "description": row["subtitle"],
        "status": "scheduled",
    }


def main():
    page = ea.fetch(LIST_URL)
    months = month_options(page)
    cutoff = ea.horizon()

    seen = {}
    for ym in months:
        if ym == "all":
            continue
        y, m = (int(x) for x in ym.split("-"))
        month_start = datetime.date(y, m, 1)
        if month_start > cutoff:
            continue
        mpage = ea.fetch(f"{LIST_URL}?month={ym}")
        for row in parse_month(mpage, ym):
            seen[row["source_id"]] = row

    records = []
    for row in seen.values():
        rec = build(row)
        if rec:
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
