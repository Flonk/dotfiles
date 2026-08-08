import datetime
import re
import sys

import ea

BASE = "https://www.burgkino.at"
VENUE = "Burg Kino"
ADDRESS = "Opernring 19, 1010 Vienna"
DISTRICT = 1010

LIST_PAGES = ["/", "/showtimes/this-week", "/showtimes/next-week", "/coming-soon"]

MOVIE_RE = re.compile(r"/movie/([a-z0-9-]+)")
TITLE_RE = re.compile(r'<h1 class="page-header">\s*<span>(.*?)</span>', re.S)
GENRE_RE = re.compile(
    r'field--name-field-genre[^"]*"[^>]*>\s*<div class="field--label">Genre</div>\s*'
    r'<div class="field--item">(.*?)</div>', re.S)
PLANNED_RE = re.compile(
    r'field--name-field-planned-start-date[^"]*"[^>]*>\s*<div class="field--label">Starting</div>\s*'
    r'<div class="field--item"><time datetime="([^"]+)"', re.S)

ROW_RE = re.compile(
    r'<tr>\s*'
    r'<td[^>]*>\s*<time[^>]*>([^<]+)</time>\s*</td>\s*'
    r'<td[^>]*>\s*<time[^>]*>([^<]+)</time>\s*</td>\s*'
    r'<td[^>]*>([^<]*)</td>\s*'
    r'<td[^>]*>([^<]*)</td>\s*'
    r'<td[^>]*>(.*?)</td>\s*'
    r'</tr>', re.S)

SHOWID_RE = re.compile(r"show_id=(\d+)")
DATE_TXT_RE = re.compile(r"(\d{2})\.(\d{2})\.(\d{4})")
TIME_TXT_RE = re.compile(r"^(\d{1,2}):(\d{2})$")


def gather_slugs():
    slugs = set()
    planned = {}
    for path in LIST_PAGES:
        try:
            html = ea.fetch(BASE + path, timeout=60)
        except Exception as e:
            sys.stderr.write(f"fetch failed {path}: {e}\n")
            continue
        slugs.update(MOVIE_RE.findall(html))
        if path == "/coming-soon":
            for block in html.split("<article"):
                m = PLANNED_RE.search(block)
                mm = MOVIE_RE.search(block)
                if m and mm:
                    d = m.group(1)[:10]
                    planned.setdefault(mm.group(1), d)
    return sorted(slugs), planned


def parse_movie(slug, planned_start):
    url = f"{BASE}/movie/{slug}"
    try:
        html = ea.fetch(url, timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed {url}: {e}\n")
        return []
    tm = TITLE_RE.search(html)
    title = ea.text(tm.group(1)) if tm else slug.replace("-", " ").title()
    gm = GENRE_RE.search(html)
    category = ea.text(gm.group(1)) if gm else None

    now = datetime.datetime.now()
    records = []
    for m in ROW_RE.finditer(html):
        date_txt, time_txt, room, price_txt, ticket_cell = m.groups()
        dm = DATE_TXT_RE.search(date_txt)
        tmm = TIME_TXT_RE.search(time_txt.strip())
        if not dm or not tmm:
            continue
        dd, mo, yy = dm.groups()
        hh, mi = tmm.groups()
        start = f"{yy}-{mo}-{dd}T{hh.zfill(2)}:{mi}"
        try:
            start_dt = datetime.datetime(int(yy), int(mo), int(dd), int(hh), int(mi))
        except ValueError:
            continue
        if start_dt < now:
            continue
        sid = SHOWID_RE.search(ticket_cell)
        source_id = f"{slug}-{sid.group(1)}" if sid else f"{slug}-{start}"
        price_min, price_text = ea.price(price_txt)
        room = ea.text(room)
        records.append({
            "source": "burgkino",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": f"{VENUE} ({room})" if room else VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
            "description": None,
            "status": "scheduled",
        })

    if not records and planned_start:
        d = planned_start
        try:
            y, mo, dd = (int(x) for x in d.split("-"))
            if datetime.date(y, mo, dd) >= datetime.date.today():
                records.append({
                    "source": "burgkino",
                    "source_id": f"{slug}-planned",
                    "url": url,
                    "title": title,
                    "start": d,
                    "end": None,
                    "venue": VENUE,
                    "district": DISTRICT,
                    "city": "Wien",
                    "address": ADDRESS,
                    "price_min": None,
                    "price_text": None,
                    "category": category,
                    "description": None,
                    "status": "scheduled",
                })
        except ValueError:
            pass
    return records


def main():
    slugs, planned = gather_slugs()
    cutoff = ea.horizon()
    records = []
    for slug in slugs:
        for rec in parse_movie(slug, planned.get(slug)):
            start_date = rec["start"][:10]
            y, mo, d = (int(x) for x in start_date.split("-"))
            if datetime.date(y, mo, d) > cutoff:
                continue
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
