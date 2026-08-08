import datetime
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://www.zoovienna.at"
LIST_URL = BASE + "/termine/"

EVENT_ITEM_RE = re.compile(
    r'event-item__header">\s*<a href="([^"]+)">([^<]+)</a>', re.S)
FILTER_RE = re.compile(
    r'name="t" id="e\d+" value="(\d+)"[^>]*>\s*<label for="e\d+">([^<]+)</label>')

OCC_LI_RE = re.compile(r'<li>([^<]*)</li>')
OCC_RE = re.compile(
    r'^[A-Za-zÄÖÜäöü]{2},\s*(\d{1,2})\.(\d{1,2})\.(\d{4})'
    r'(?:,\s*(\d{1,2}):(\d{2})(?:\s*(?:bis|-)\s*(\d{1,2}):(\d{2}))?\s*Uhr)?'
    r'(?:[:,]\s*(.*))?$')

COST_RE = re.compile(
    r'Kosten:?\s*(?:</strong>)?\s*(.*?)(?:<br|</p>)', re.S)
DESC_RE = re.compile(r'editable-content">\s*<p>(.*?)</p>', re.S)


def month_list():
    today = datetime.date.today()
    cutoff = ea.horizon()
    months = []
    y, m = today.year, today.month
    while True:
        months.append((y, m))
        if y > cutoff.year or (y == cutoff.year and m >= cutoff.month):
            break
        m += 1
        if m > 12:
            m = 1
            y += 1
    return months


def fetch_month(year, month, t=None):
    url = f"{LIST_URL}?year={year}&month={month}"
    if t is not None:
        url += f"&t={t}"
    return ea.fetch(url)


def discover_events():
    events = {}
    for y, m in month_list():
        page = fetch_month(y, m)
        for href, title in EVENT_ITEM_RE.findall(page):
            if href not in events:
                events[href] = {"title": ea.text(title), "month": (y, m)}
    return events


def category_for(href, month, filters):
    y, m = month
    for t, label in filters.items():
        page = fetch_month(y, m, t)
        if any(h == href for h, _ in EVENT_ITEM_RE.findall(page)):
            return label
    return None


def parse_occurrences(dpage):
    i = dpage.find("next-event-dates")
    if i < 0:
        return []
    j = dpage.find("</aside>", i)
    block = dpage[i:j] if j > 0 else dpage[i:]
    out = []
    for raw in OCC_LI_RE.findall(block):
        raw = ea.text(raw)
        if not raw or "keine Termine" in raw:
            continue
        m = OCC_RE.match(raw)
        if not m:
            continue
        d, mo, y, h1, mi1, h2, mi2, note = m.groups()
        date = f"{int(y):04d}-{int(mo):02d}-{int(d):02d}"
        start = f"{date}T{int(h1):02d}:{mi1}" if h1 else date
        end = f"{date}T{int(h2):02d}:{mi2}" if h2 else None
        out.append((start, end, (note or "").strip() or None))
    return out


def main():
    front = ea.fetch(LIST_URL)
    filters = {t: label for t, label in FILTER_RE.findall(front)}

    events = discover_events()

    records = []
    for href, info in events.items():
        url = BASE + href
        slug = href.strip("/").rsplit("/", 1)[-1]
        try:
            dpage = ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"skip {url}: {e}\n")
            continue

        occs = parse_occurrences(dpage)
        if not occs:
            continue

        cat = category_for(href, info["month"], filters)

        cm = COST_RE.search(dpage)
        price_text = ea.text(cm.group(1)) if cm else None
        price_min, _ = ea.price(price_text) if price_text else (None, None)

        dm = DESC_RE.search(dpage)
        description = ea.text(dm.group(1)) if dm else None

        cutoff = ea.horizon()
        for start, end, note in occs:
            start_date = datetime.date.fromisoformat(start[:10])
            if start_date > cutoff:
                continue
            title = info["title"]
            extra = {}
            if note:
                if note.lower() in ("ausgebucht",):
                    extra["sold_out"] = True
                else:
                    title = f"{title} – {note}"
            records.append({
                "source": "zoovienna",
                "source_id": f"{slug}-{start}",
                "url": url,
                "title": title,
                "start": start,
                "end": end,
                "venue": "Tiergarten Schönbrunn",
                "district": 1130,
                "city": "Wien",
                "price_min": price_min,
                "price_text": price_text,
                "category": cat,
                "description": description,
                "extra": extra or None,
            })

    ea.emit(records)


if __name__ == "__main__":
    main()
