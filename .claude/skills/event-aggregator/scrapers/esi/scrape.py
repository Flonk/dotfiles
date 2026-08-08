import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://www.esi.ac.at"
URL = BASE + "/events/"
VENUE = "Erwin Schrödinger Institute"
ADDRESS = "Boltzmanngasse 9, 1090 Wien"

MONTHS = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12,
}


def month_num(name):
    return MONTHS.get(name.strip(".").lower()[:4]) or MONTHS.get(name.strip(".").lower()[:3])


def parse_date(mon, day, year):
    mo = month_num(mon)
    if not mo:
        return None
    return f"{int(year):04d}-{mo:02d}-{int(day):02d}"


def parse_range(s):
    s = ea.html.unescape(s)
    m = re.search(
        r"([A-Za-z]+)\.?\s+(\d{1,2}),\s+(\d{4})\s*(?:&mdash;|—|-)\s*"
        r"([A-Za-z]+)\.?\s+(\d{1,2}),\s+(\d{4})", s)
    if m:
        start = parse_date(m.group(1), m.group(2), m.group(3))
        end = parse_date(m.group(4), m.group(5), m.group(6))
        return start, end
    m = re.search(r"([A-Za-z]+)\.?\s+(\d{1,2}),\s+(\d{4})", s)
    if m:
        d = parse_date(m.group(1), m.group(2), m.group(3))
        return d, None
    return None, None


def parse_events(page):
    out = []
    tab = re.search(
        r'id="tab-events">(.*?)<div class="tab-pane', page, re.S)
    block = tab.group(1) if tab else page
    for dd in re.finditer(r"<dd class=\"event-item\">(.*?)</dd>", block, re.S):
        chunk = dd.group(1)
        m = re.search(r'<a href="([^"]+)">([^<]*)</a>', chunk)
        if not m:
            continue
        href, title = m.group(1), ea.text(m.group(2))
        spans = re.findall(r'<span class="event-item-detail">(.*?)</span>',
                            chunk, re.S)
        if not spans:
            continue
        start, end = parse_range(spans[0])
        if not start:
            continue
        category = ea.text(spans[1]) if len(spans) > 1 else None
        source_id = href.strip("/").split("/")[-1]
        url = BASE + href if href.startswith("/") else href
        out.append({
            "source": "esi",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": VENUE,
            "district": 1090,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": category,
        })
    return out


def parse_talks(page):
    out = []
    tab = re.search(r'id="tab-talks">\s*<dl class="event-list">(.*?)</dl>',
                     page, re.S)
    if not tab:
        return out
    block = tab.group(1)
    cur_date = None
    for dd in re.finditer(r"<dd class=\"event-item\">(.*?)</dd>", block, re.S):
        chunk = dd.group(1)
        hm = re.search(r"<h2[^>]*>([^<]*)</h2>", chunk)
        if hm:
            m = re.search(r"([A-Za-z]+)\s+(\d{1,2})\.\s+(\d{4})",
                           ea.html.unescape(hm.group(1)))
            if m:
                cur_date = parse_date(m.group(1), m.group(2), m.group(3))
            continue
        am = re.search(r'<a href="([^"]+)">([^<]*)</a>', chunk)
        if not am:
            continue
        href, title = am.group(1), ea.text(am.group(2))
        speaker_m = re.search(
            r'<span class="event-item-detail">\s*([^<]*?)\s*</span>', chunk)
        speaker = ea.text(speaker_m.group(1)) if speaker_m else None
        tm = re.search(r"(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})", chunk)
        start = cur_date
        end = None
        if start and tm:
            start = f"{cur_date}T{int(tm.group(1)):02d}:{tm.group(2)}"
            end = f"{cur_date}T{int(tm.group(3)):02d}:{tm.group(4)}"
        if not start:
            continue
        parent_m = re.search(r'Part of <a href="[^"]+">([^<]*)</a>', chunk)
        source_id = href.strip("/").split("/")[-1]
        url = BASE + href if href.startswith("/") else href
        out.append({
            "source": "esi",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": VENUE,
            "district": 1090,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": "Talk",
            "description": ("Speaker: " + speaker) if speaker else None,
            "extra": {"part_of": ea.text(parent_m.group(1))} if parent_m else None,
        })
    return out


def main():
    page = ea.fetch(URL, cache=os.path.join(os.path.dirname(__file__), "page.html"))
    records = parse_events(page) + parse_talks(page)
    ea.emit(records)


if __name__ == "__main__":
    main()
