import datetime
import re
import sys

import ea

BASE = "https://schikaneder.at"
VENUE = "Schikaneder"
ADDRESS = "Schleifmühlgasse 8/14, 1040 Wien"
DISTRICT = 1040

ID_RE = re.compile(r"veranstaltung_id=(\d+)")
TITLE_RE = re.compile(r'<h1 class="detail-titel">(.*?)</h1>', re.S)
SUBINFO_RE = re.compile(r'<div class="subinfo">(.*?)</div>', re.S)
KURZ_RE = re.compile(r'<div class="kurzbeschreibung">(.*?)</div>', re.S)
TERMIN_RE = re.compile(
    r'data-titel="[^"]*"\s+data-termin_id="(\d+)"\s+data-free-tickets="[^"]*"\s+'
    r'data-raum="([^"]*)"\s+data-datum="([^"]+)"', re.S)
PRICE_RE = re.compile(
    r'<strong[^>]*><span[^>]*>([\d,]+)\s*EUR</span></strong><span[^>]*>\s*Normalpreis', re.S)

MAX_EMPTY_STREAK = 14


def fetch_default_price():
    try:
        html = ea.fetch(f"{BASE}/kino/kinoprogramm", timeout=30)
    except Exception as e:
        sys.stderr.write(f"fetch failed default price page: {e}\n")
        return None, None
    m = PRICE_RE.search(html)
    if not m:
        return None, None
    val = float(m.group(1).replace(",", "."))
    return val, f"{m.group(1)} EUR Normalpreis (Standardpreis lt. Website, sofern nicht anders angegeben)"


def collect_ids(cutoff):
    ids = set()
    day = datetime.date.today()
    empty_streak = 0
    while day <= cutoff and empty_streak < MAX_EMPTY_STREAK:
        url = f"{BASE}/kino/kinoprogramm?date={day.isoformat()}"
        try:
            html = ea.fetch(url, timeout=30)
        except Exception as e:
            sys.stderr.write(f"fetch failed {url}: {e}\n")
            day += datetime.timedelta(days=1)
            continue
        found = set(ID_RE.findall(html))
        empty_streak = 0 if found else empty_streak + 1
        ids |= found
        day += datetime.timedelta(days=1)
    return ids


def parse_detail(vid, price_min, price_text):
    url = f"{BASE}/kino/veranstaltung_detail?veranstaltung_id={vid}"
    try:
        html = ea.fetch(url, timeout=30)
    except Exception as e:
        sys.stderr.write(f"fetch failed {url}: {e}\n")
        return []
    tm = TITLE_RE.search(html)
    title = ea.text(tm.group(1)) if tm else None
    if not title:
        return []
    sm = SUBINFO_RE.search(html)
    subinfo = ea.text(sm.group(1)) if sm else None
    km = KURZ_RE.search(html)
    desc = ea.text(km.group(1)) if km else None
    description = " ".join(x for x in (subinfo, desc) if x) or None

    records = []
    for termin_id, raum, datum in TERMIN_RE.findall(html):
        start = ea.de_date(datum.strip())
        if not start:
            continue
        raum = ea.text(raum)
        records.append({
            "source": "schikaneder",
            "source_id": termin_id,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": f"{VENUE} ({raum})" if raum else VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": price_min,
            "price_text": price_text,
            "category": None,
            "description": description,
            "status": "scheduled",
        })
    return records


def main():
    cutoff = ea.horizon()
    price_min, price_text = fetch_default_price()
    ids = collect_ids(cutoff)
    records = []
    for vid in sorted(ids):
        records.extend(parse_detail(vid, price_min, price_text))

    now = datetime.datetime.now()
    out = []
    for r in records:
        start = r["start"]
        try:
            dt = (datetime.datetime.strptime(start, "%Y-%m-%dT%H:%M")
                  if len(start) > 10 else datetime.datetime.strptime(start, "%Y-%m-%d"))
        except ValueError:
            continue
        if dt.date() > cutoff:
            continue
        if dt < now - datetime.timedelta(hours=6):
            continue
        out.append(r)
    ea.emit(out)


if __name__ == "__main__":
    main()
