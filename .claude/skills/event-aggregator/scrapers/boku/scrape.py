import datetime
import re
import sys
import time
import urllib.error

import ea

BASE = "https://boku.ac.at"

START_RE = re.compile(r'<a class="corner-link" href="(/event/details/(\d+))">')
TITLE_RE = re.compile(r'<h4>(.*?)</h4>', re.S)
CAT_RE = re.compile(
    r'<ul class="list-inline no-padding" title="Kategorie">.*?<strong[^>]*>(.*?)</strong>', re.S)
TEASER_RE = re.compile(r'<p class="eventnews-teaser">(.*?)</p>', re.S)

ICS_FIELD_RE = re.compile(r'^([A-Z\-]+)(?:;[^:]*)?:(.*)$')
FREE_RE = re.compile(r'\b(frei|gratis|kostenlos|kostenfrei|eintritt frei)\b', re.I)


def month_iter(start, end):
    y, m = start.year, start.month
    while (y, m) <= (end.year, end.month):
        yield y, m
        m += 1
        if m == 13:
            m = 1
            y += 1


def parse_list(page):
    out = []
    starts = list(START_RE.finditer(page))
    for i, m in enumerate(starts):
        href, eid = m.group(1), m.group(2)
        end = starts[i + 1].start() if i + 1 < len(starts) else len(page)
        block = page[m.end():end]
        tm = TITLE_RE.search(block)
        title = ea.text(tm.group(1)) if tm else None
        cm = CAT_RE.search(block)
        category = ea.text(cm.group(1)) if cm else None
        teaser_m = TEASER_RE.search(block)
        teaser = ea.text(teaser_m.group(1)) if teaser_m else None
        out.append({
            "id": eid,
            "url": BASE + href,
            "title": title,
            "category": category,
            "teaser": teaser,
        })
    return out


def unfold(ics_text):
    lines = ics_text.replace("\r\n", "\n").split("\n")
    out = []
    for line in lines:
        if line.startswith((" ", "\t")) and out:
            out[-1] += line[1:]
        else:
            out.append(line)
    return out


def parse_ics(ics_text):
    fields = {}
    for line in unfold(ics_text):
        m = ICS_FIELD_RE.match(line)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        val = val.replace("\\,", ",").replace("\\n", " ").replace("\\;", ";").strip()
        if key in ("DTSTART", "DTEND", "SUMMARY", "DESCRIPTION", "LOCATION"):
            fields[key] = val
    return fields


def ics_dt(s):
    if not s:
        return None
    m = re.match(r"(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?", s)
    if not m:
        return None
    y, mo, d, h, mi = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
    out = f"{y}-{mo}-{d}"
    if h is not None:
        out += f"T{h}:{mi}"
    return out


def parse_location(loc):
    if not loc:
        return None, None, None
    m = re.search(r'(\d{4})\s+([A-Za-zÄÖÜäöüß][\wÄÖÜäöüß\-\.\' ]*)$', loc)
    if not m:
        return None, None, None
    plz = int(m.group(1))
    city = m.group(2).strip()
    district = plz if 1010 <= plz <= 1230 else None
    return district, city, loc


def main():
    today = datetime.date.today()
    horizon = ea.horizon()

    seen = {}
    order = []
    for y, m in month_iter(today, horizon):
        url = f"{BASE}/event/list/{y}/{m}"
        page = None
        for attempt in range(3):
            try:
                page = ea.fetch(url)
                break
            except urllib.error.HTTPError as e:
                sys.stderr.write(f"{url}: {e}\n")
                break
            except Exception as e:
                sys.stderr.write(f"{url} attempt {attempt}: {e}\n")
                time.sleep(1)
        if page is None:
            continue
        for item in parse_list(page):
            if item["id"] not in seen:
                seen[item["id"]] = item
                order.append(item["id"])

    records = []
    for eid in order:
        item = seen[eid]
        ics_url = f"{BASE}/event/details/{eid}.ics"
        ics_text = None
        for attempt in range(3):
            try:
                ics_text = ea.fetch(ics_url)
                break
            except Exception as e:
                sys.stderr.write(f"{ics_url} attempt {attempt}: {e}\n")
                time.sleep(1)
        if not ics_text:
            continue
        f = parse_ics(ics_text)
        start = ics_dt(f.get("DTSTART"))
        end = ics_dt(f.get("DTEND"))
        if not start:
            continue
        if end and end < start:
            end = None

        cutoff = end or start
        if cutoff[:10] < today.isoformat():
            continue

        title = f.get("SUMMARY") or item["title"]
        if not title:
            continue
        description = f.get("DESCRIPTION") or item["teaser"]

        district, city, address = parse_location(f.get("LOCATION"))
        venue = f.get("LOCATION") or None

        price_min = price_text = None
        blob = " ".join(filter(None, [description, item["teaser"]]))
        if FREE_RE.search(blob):
            price_min, price_text = 0.0, "gratis/frei"

        records.append({
            "source": "boku",
            "source_id": eid,
            "url": item["url"],
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": district,
            "city": city,
            "address": address,
            "price_min": price_min,
            "price_text": price_text,
            "category": item["category"],
            "description": description,
            "status": "scheduled",
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
