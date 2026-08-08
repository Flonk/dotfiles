import datetime
import json
import re
import sys
import urllib.parse
import urllib.request

import ea

CAL_URL = ("https://www.mak.at/jart/prj3/mak-resp/main.jart"
           "?reserve-mode=reserve&content-id=1414100174649&rel=de")
AUSST_INDEX = "https://www.mak.at/programm/ausstellungen"
BASE = "https://www.mak.at"

VENUE_INFO = {
    "MAK – Museum für angewandte Kunst": ("Stubenring 5", 1010),
    "MAK Geymüllerschlössel": ("Khevenhüllerstraße 2", 1180),
}

ENTRY_RE = re.compile(
    r'<article class="kalender-list-entry.*?</article>', re.S)
LDJSON_RE = re.compile(
    r'<script type="application/ld\+json">(.*?)</script>', re.S)
DATE_RE = re.compile(
    r'<div class="entry-date d-flex justify-content-between">\s*<div>.*?</div>'
    r'\s*<div class="[^"]*text-end">\s*(.*?)\s*</div>', re.S)
TITLE_RE = re.compile(
    r'class="event-titel">\s*<a href="([^"]+)">(.*?)</a>', re.S)
SUBTITLE_RE = re.compile(
    r'class="event-subtitel">\s*(.*?)\s*</div>', re.S)
LOCATION_RE = re.compile(r'class="entry-location">([^<]*)</div>')


def fetch_post(url, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers={
        "User-Agent": ea.UA,
        "Accept-Language": "de-AT,de;q=0.9,en;q=0.8",
        "Content-Type": "application/x-www-form-urlencoded",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def cal_records():
    page = fetch_post(CAL_URL, {
        "jahr": "", "events-limit": "300", "sel-start": "0",
    })
    cutoff = ea.horizon()
    out = []
    for art in ENTRY_RE.findall(page):
        lj = LDJSON_RE.search(art)
        if not lj:
            continue
        try:
            d = json.loads(lj.group(1).strip())
        except Exception:
            continue
        start = d.get("startDate")
        if not start:
            continue
        try:
            start_date = datetime.date.fromisoformat(start[:10])
        except ValueError:
            continue
        if start_date > cutoff:
            continue

        tm = TITLE_RE.search(art)
        if not tm:
            continue
        href, title_html = tm.groups()
        title = ea.text(title_html)
        if not title:
            continue
        url = href if href.startswith("http") else BASE + href
        source_id = href.rsplit("/", 1)[-1]

        dm = DATE_RE.search(art)
        category = None
        if dm:
            lines = [ea.text(ln) for ln in re.split(r'<br\s*/?>', dm.group(1))]
            lines = [x for x in lines if x]
            if len(lines) >= 2:
                category = lines[-1]

        sm = SUBTITLE_RE.search(art)
        description = ea.text(sm.group(1)) if sm else None

        loc = d.get("location") or {}
        venue = loc.get("name")
        lm = LOCATION_RE.search(art)
        if lm:
            venue = ea.text(lm.group(1)) or venue

        address, dist = VENUE_INFO.get(venue, (None, None))

        out.append({
            "source": "mak",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": dist,
            "city": "Wien",
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": description,
            "status": "scheduled",
        })
    return out


DATE_RANGE_RE = re.compile(
    r'<div class="date">\s*(\d{1,2})\.(\d{1,2})\.(\d{4})&mdash;'
    r'(\d{1,2})\.(\d{1,2})\.(\d{4})\s*</div>', re.S)
ROOM_RE = re.compile(r'<span class="room">([^<]*)</span>')
TITLE_H1_RE = re.compile(r'<h1 class="title">([^<]*)')
TEXT_RE = re.compile(r'class="ausstellung-text lead">\s*(.*?)\s*</div>', re.S)


def ausstellung_records():
    idx = ea.fetch(AUSST_INDEX)
    slugs = sorted(set(re.findall(
        r'href="/programm/ausstellungen/([a-z0-9_]+)"', idx)))
    today = datetime.date.today()
    out = []
    for slug in slugs:
        url = f"{BASE}/programm/ausstellungen/{slug}"
        try:
            page = ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"skip {slug}: {e}\n")
            continue
        dm = DATE_RANGE_RE.search(page)
        if not dm:
            continue
        d1, m1, y1, d2, m2, y2 = dm.groups()
        start = f"{y1}-{int(m1):02d}-{int(d1):02d}"
        end = f"{y2}-{int(m2):02d}-{int(d2):02d}"
        if datetime.date.fromisoformat(end) < today:
            continue

        tm = TITLE_H1_RE.search(page)
        title = ea.text(tm.group(1)) if tm else slug
        if not title:
            continue

        rm = ROOM_RE.search(page)
        room = ea.text(rm.group(1)) if rm else None
        external = bool(room and "," in room)
        if external:
            venue, address, dist, city = room, None, None, None
        else:
            venue = f"MAK – {room}" if room else "MAK – Museum für angewandte Kunst"
            address, dist = VENUE_INFO["MAK – Museum für angewandte Kunst"]
            city = "Wien"

        txm = TEXT_RE.search(page)
        description = ea.text(txm.group(1)) if txm else None

        out.append({
            "source": "mak",
            "source_id": slug,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": dist,
            "city": city,
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": "Ausstellung",
            "description": description,
            "status": "scheduled",
        })
    return out


def main():
    records = cal_records() + ausstellung_records()
    ea.emit(records)


if __name__ == "__main__":
    main()
