import datetime
import json
import re
import sys
import urllib.request

import ea

API_URL = "https://www.wko.at/api/event/filter"
SOURCE = "wko"

DATE_RE = re.compile(
    r'<svg class="icon icon-date">.*?</svg>\s*(.*?)\s*</div>', re.S)
TITLE_RE = re.compile(r'class="card-title h4">\s*<a href="[^"]+">(.*?)</a>', re.S)
LOC_RE = re.compile(
    r'<svg class="icon icon-(pin|video)">.*?</svg>\s*(.*?)\s*</div>', re.S)

MON = {
    "Jan": 1, "Feb": 2, "Mär": 3, "Apr": 4, "Mai": 5, "Jun": 6,
    "Jul": 7, "Aug": 8, "Sep": 9, "Okt": 10, "Nov": 11, "Dez": 12,
}

SINGLE_DT_RE = re.compile(
    r"(\d{2})\. (\w{3})\. (\d{4}), (\d{2}):(\d{2}) Uhr")
RANGE_RE = re.compile(
    r"(\d{2})\. (\w{3})\. (\d{4}) . (\d{2})\. (\w{3})\. (\d{4})")
SINGLE_D_RE = re.compile(r"(\d{2})\. (\w{3})\. (\d{4})$")


def parse_dates(txt):
    m = SINGLE_DT_RE.search(txt)
    if m:
        d, mon, y, h, mi = m.groups()
        start = f"{y}-{MON[mon]:02d}-{int(d):02d}T{h}:{mi}"
        return start, None
    m = RANGE_RE.search(txt)
    if m:
        d1, mon1, y1, d2, mon2, y2 = m.groups()
        start = f"{y1}-{MON[mon1]:02d}-{int(d1):02d}"
        end = f"{y2}-{MON[mon2]:02d}-{int(d2):02d}"
        return start, end
    m = SINGLE_D_RE.search(txt)
    if m:
        d, mon, y = m.groups()
        start = f"{y}-{MON[mon]:02d}-{int(d):02d}"
        return start, None
    return None, None


def fetch_batch(offset, count=200):
    body = json.dumps({
        "count": count, "offsetCurrent": offset, "aktuelle": True,
        "place": "Österreich", "withStorniert": False,
        "withAusgebucht": False, "withAbgeschlossen": False,
        "von": "", "bis": "", "veranstaltungstyp": "", "zielgruppe": "",
        "kategorie": "",
    }).encode()
    req = urllib.request.Request(API_URL, data=body, headers={
        "User-Agent": ea.UA,
        "Accept-Language": "de-AT,de;q=0.9,en;q=0.8",
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def main():
    cutoff = ea.horizon()
    records = []
    seen = set()
    offset = 0
    total = None
    while True:
        try:
            data = fetch_batch(offset)
        except Exception as e:
            sys.stderr.write(f"fetch failed at offset {offset}: {e}\n")
            break
        elements = data.get("elements") or []
        total = data.get("totalCount")
        if total is not None:
            total = int(total)
        if not elements:
            break
        batch_max = None
        for el in elements:
            im = re.search(r'data-gtm-item-id="([^"]+)"', el)
            um = re.search(r'data-gtm-item-url="([^"]+)"', el)
            if not im or not um:
                continue
            event_id, url = im.group(1), um.group(1)
            if event_id in seen:
                continue
            seen.add(event_id)

            tm = TITLE_RE.search(el)
            title = ea.text(tm.group(1)) if tm else None
            if not title:
                continue

            dm = DATE_RE.search(el)
            date_txt = ea.text(dm.group(1)) if dm else ""
            start, end = parse_dates(date_txt or "")
            if not start:
                continue

            try:
                start_date = datetime.date.fromisoformat(start[:10])
            except ValueError:
                start_date = None
            if start_date and (batch_max is None or start_date > batch_max):
                batch_max = start_date

            venue = None
            district = None
            city = None
            is_online = False
            lm = LOC_RE.search(el)
            if lm:
                kind, val = lm.group(1), ea.text(lm.group(2))
                if kind == "video":
                    is_online = True
                    venue = val
                elif val:
                    venue = val
                    dm2 = re.match(r"(\d{4,5})\s+(.*)", val)
                    if dm2:
                        plz, city = dm2.groups()
                        district = ea.district(plz)

            extra = {"online": True} if is_online else None

            records.append({
                "source": SOURCE,
                "source_id": event_id,
                "url": url,
                "title": title,
                "start": start,
                "end": end,
                "venue": venue,
                "district": district,
                "city": city,
                "address": None,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": None,
                "extra": extra,
            })

        offset += len(elements)
        if total is not None and offset >= total:
            break
        if batch_max and batch_max > cutoff + datetime.timedelta(days=30):
            break
        if offset > 4000:
            break

    ea.emit(records)


if __name__ == "__main__":
    main()
