import datetime
import re
import sys

import ea

BASE = "https://www.votivkino.at"

VENUES = {
    "votiv": {
        "name": "Votiv Kino",
        "district": 1090,
        "address": "Währinger Straße 12, 1090 Wien",
    },
    "defrance": {
        "name": "Kino De France",
        "district": 1010,
        "address": "Heßgasse 7, 1010 Wien",
    },
}

FILM_CARD_START = re.compile(r'<li id="film_card_\d+"')
FILM_URL_RE = re.compile(r'<a href="(https://www\.votivkino\.at/film/[a-z0-9-]+/)"')
TITLE_RE = re.compile(
    r'<span class="title-heading block fChalet fs\d+ ls0 no-wrap">(.*?)</span>', re.S)
DESC_RE = re.compile(
    r'<div class="card-hover-text fFGLight fs18 lh13">(.*?)</div>', re.S)
PRODUCTION_RE = re.compile(
    r'<i class="card-hover-production pad-def">(.*?)</i>', re.S)
DURATION_RE = re.compile(
    r'<i class="card-hover-duration pad-def">(.*?)</i>', re.S)
SHOWTIME_LI_RE = re.compile(r'<li id="stuid_[a-z0-9]+".*?</li>', re.S)
SHOWTIME_DATA_RE = re.compile(r'data-showtime="(\d{4}-\d{2}-\d{2})T')
SHOWTIME_VENUE_RE = re.compile(r'showtime_kino_(votiv|defrance|bellaria)')
SHOWTIME_TIME_RE = re.compile(r'<span class="date[^"]*">.*?(\d{1,2}:\d{2})\s*</span>', re.S)
SHOWTIME_ROOM_RE = re.compile(
    r'location fs14 ls05 pad-showtimes">.*?<span class="xs-hidden">([^<]+)</span>', re.S)
SHOWTIME_OMU_RE = re.compile(r'<abbr class="omu" title="[^"]*">([^<]*)</abbr>')
SHOWTIME_SHOWID_RE = re.compile(r'href="/t/\?show=(\d+)"')

CATEGORY_RE = re.compile(r'category-wrapper.*?<i>([^<]+)</i>', re.S)

VORSCHAU_START_RE = re.compile(r'<li class="card col grid always-visible')
VORSCHAU_DATE_RE = re.compile(r'<time datetime="(\d{4}-\d{2}-\d{2})" class="date fCoign')


def parse_cards(page_html):
    records = []
    starts = [m.start() for m in FILM_CARD_START.finditer(page_html)]
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(page_html)
        block = page_html[start:end]

        head, _, _ = block.partition('<div class="card-showtimes')
        um = FILM_URL_RE.search(head)
        if not um:
            continue
        film_url = um.group(1)
        tm = TITLE_RE.search(head)
        title = ea.text(tm.group(1)) if tm else None
        if not title:
            continue
        dm = DESC_RE.search(head)
        description = ea.text(dm.group(1)) if dm else None
        pm = PRODUCTION_RE.search(head)
        production = ea.text(pm.group(1)) if pm else None
        durm = DURATION_RE.search(head)
        duration_text = ea.text(durm.group(1)) if durm else None
        cm = CATEGORY_RE.search(head)
        category = ea.text(cm.group(1)) if cm else None

        for lim in SHOWTIME_LI_RE.finditer(block):
            li = lim.group(0)
            vm = SHOWTIME_VENUE_RE.search(li)
            if not vm or vm.group(1) not in VENUES:
                continue
            dsm = SHOWTIME_DATA_RE.search(li)
            tim = SHOWTIME_TIME_RE.search(li)
            if not dsm or not tim:
                continue
            room_m = SHOWTIME_ROOM_RE.search(li)
            room = ea.text(room_m.group(1)) if room_m else None
            omu_m = SHOWTIME_OMU_RE.search(li)
            version = ea.text(omu_m.group(1)) if omu_m else None
            sid_m = SHOWTIME_SHOWID_RE.search(li)
            show_id = sid_m.group(1) if sid_m else None
            records.append({
                "film_url": film_url,
                "title": title,
                "description": description,
                "production": production,
                "duration_text": duration_text,
                "category": category,
                "venue_key": vm.group(1),
                "date_iso": dsm.group(1),
                "time_txt": tim.group(1),
                "room": room,
                "version": version,
                "show_id": show_id,
            })
    return records


def build_record(card):
    venue = VENUES[card["venue_key"]]
    hh, mm = card["time_txt"].split(":")
    start = f"{card['date_iso']}T{int(hh):02d}:{mm}"
    source_id = card["show_id"] or f"{card['film_url']}-{start}"
    extra = {}
    if card["production"]:
        extra["production"] = card["production"]
    if card["duration_text"]:
        extra["duration_text"] = card["duration_text"]
    if card["version"]:
        extra["version"] = card["version"]
    if card["room"]:
        extra["room"] = card["room"]
    return {
        "source": "votivkino",
        "source_id": source_id,
        "url": card["film_url"],
        "title": card["title"],
        "start": start,
        "end": None,
        "venue": f"{venue['name']} ({card['room']})" if card["room"] else venue["name"],
        "district": venue["district"],
        "city": "Wien",
        "address": venue["address"],
        "price_min": None,
        "price_text": None,
        "category": card["category"],
        "description": card["description"],
        "status": "scheduled",
        "extra": extra,
    }


def fetch_day(date):
    url = f"{BASE}/programm/tag/?date={date.strftime('%Y%m%d')}"
    try:
        return ea.fetch(url, timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed {url}: {e}\n")
        return ""


def fetch_specials():
    try:
        return ea.fetch(f"{BASE}/specials/", timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed /specials/: {e}\n")
        return ""


def fetch_vorschau():
    try:
        return ea.fetch(f"{BASE}/vorschau/", timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed /vorschau/: {e}\n")
        return ""


def parse_vorschau(page_html):
    out = []
    starts = [m.start() for m in VORSCHAU_START_RE.finditer(page_html)]
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(page_html)
        block = page_html[start:end]
        dm = VORSCHAU_DATE_RE.search(block)
        if not dm:
            continue
        um = FILM_URL_RE.search(block)
        tm = TITLE_RE.search(block)
        if not um or not tm:
            continue
        title = ea.text(tm.group(1))
        if not title:
            continue
        out.append({"url": um.group(1), "title": title, "date": dm.group(1)})
    return out


def main():
    today = datetime.date.today()
    cutoff = ea.horizon()
    day_span = min((cutoff - today).days, 21)

    seen = set()
    records = []
    seen_films = set()

    for i in range(day_span + 1):
        d = today + datetime.timedelta(days=i)
        html = fetch_day(d)
        if not html:
            continue
        for c in parse_cards(html):
            rec = build_record(c)
            if rec["source_id"] in seen:
                continue
            seen.add(rec["source_id"])
            records.append(rec)
            seen_films.add(c["film_url"])

    today_iso = today.isoformat()
    specials_html = fetch_specials()
    if specials_html:
        for c in parse_cards(specials_html):
            if c["date_iso"] > cutoff.isoformat() or c["date_iso"] < today_iso:
                continue
            rec = build_record(c)
            if rec["source_id"] in seen:
                continue
            seen.add(rec["source_id"])
            records.append(rec)
            seen_films.add(c["film_url"])

    vorschau_html = fetch_vorschau()
    if vorschau_html:
        for v in parse_vorschau(vorschau_html):
            if v["url"] in seen_films:
                continue
            if v["date"] > cutoff.isoformat():
                continue
            source_id = f"{v['url']}-planned"
            if source_id in seen:
                continue
            seen.add(source_id)
            records.append({
                "source": "votivkino",
                "source_id": source_id,
                "url": v["url"],
                "title": v["title"],
                "start": v["date"],
                "end": None,
                "venue": None,
                "district": None,
                "city": "Wien",
                "address": None,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": None,
                "status": "scheduled",
                "extra": {"planned_start": True},
            })

    ea.emit(records)


if __name__ == "__main__":
    main()
