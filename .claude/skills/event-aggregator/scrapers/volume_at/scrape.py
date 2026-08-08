import datetime
import html
import re
import sys

import ea

BASE = "https://www.volume.at"
LIST = BASE + "/events/{}/"

HEADER_RE = re.compile(
    r'<span class="day">(\d+)</span>\s*<div>\s*<span class="weekday">[^<]*</span>\s*'
    r'<span class="month">([^<]*)</span>', re.S)
ITEM_RE = re.compile(
    r'<article[^>]*\bitem--event\b[^>]*data-content-id="(\d+)".*?</article>', re.S)
TITLE_RE = re.compile(
    r'<h2[^>]*class="item__title[^"]*">\s*<a href="([^"]+)"[^>]*>\s*<span>\s*(.*?)\s*</span>', re.S)
CANCEL_RE = re.compile(r'badge[^"]*"[^>]*>\s*abgesagt\s*<', re.I)
TYPE_RE = re.compile(r'item__eventtype">([^<]*)<')
LOC_RE = re.compile(r'item__location[^"]*"[^>]*>\s*([^<]*?)\s*</a>')
ADDR_RE = re.compile(r'location__address">\s*([^<]*?)\s*<')
OFFERS_RE = re.compile(r'item__offers">(.*?)</div>', re.S)

MONTHS = ea.MON

COMBINED = re.compile(
    r'(?P<header><span class="day">\d+</span>\s*<div>\s*<span class="weekday">[^<]*</span>\s*'
    r'<span class="month">[^<]*</span>)'
    r'|(?P<item><article[^>]*\bitem--event\b[^>]*data-content-id="\d+".*?</article>)', re.S)


def parse_page(page, cursor):
    last = cursor - datetime.timedelta(days=1)
    out = []
    dates_seen = []
    for m in COMBINED.finditer(page):
        if m.group("header"):
            hm = HEADER_RE.match(m.group("header"))
            if not hm:
                continue
            day = int(hm.group(1))
            month = MONTHS.get(hm.group(2).strip())
            if not month:
                continue
            year = last.year
            try:
                dt = datetime.date(year, month, day)
            except ValueError:
                continue
            if dt < last:
                dt = datetime.date(year + 1, month, day)
            last = dt
            dates_seen.append(dt)
        else:
            block = m.group("item")
            tm = TITLE_RE.search(block)
            if not tm:
                continue
            url = tm.group(1)
            if url.startswith("/"):
                url = BASE + url
            title = ea.text(html.unescape(tm.group(2)))
            if not title:
                continue
            cancelled = bool(CANCEL_RE.search(block))
            tym = TYPE_RE.search(block)
            category = ea.text(tym.group(1)) if tym else None
            locm = LOC_RE.search(block)
            venue = ea.text(locm.group(1)) if locm else None
            addrm = ADDR_RE.search(block)
            addr = ea.text(addrm.group(1)) if addrm else None
            offm = OFFERS_RE.search(block)
            price_min = price_text = None
            if offm:
                price_min, price_text = ea.price(offm.group(1))
            idm = re.search(r'data-content-id="(\d+)"', block)
            src_id = idm.group(1) if idm else url
            out.append({
                "source": "volume_at",
                "source_id": src_id,
                "url": url,
                "title": title,
                "start": last.isoformat(),
                "end": None,
                "venue": venue,
                "district": ea.district(addr),
                "city": "Wien" if addr == "Wien" else None,
                "address": None,
                "price_min": price_min,
                "price_text": price_text,
                "category": category,
                "description": None,
                "status": "cancelled" if cancelled else "scheduled",
            })
    return out, dates_seen


def main():
    cutoff = ea.horizon()
    cursor = datetime.date.today()
    seen_ids = set()
    records = []
    for _ in range(120):
        url = LIST.format(cursor.isoformat())
        try:
            page = ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"fetch failed {url}: {e}\n")
            break
        items, dates_seen = parse_page(page, cursor)
        if not dates_seen:
            break
        for r in items:
            if r["source_id"] in seen_ids:
                continue
            seen_ids.add(r["source_id"])
            records.append(r)
        cursor = max(dates_seen) + datetime.timedelta(days=1)
        if cursor > cutoff:
            break
    ea.emit(records)


if __name__ == "__main__":
    main()
