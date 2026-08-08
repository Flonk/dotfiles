import datetime
import re
import sys

import ea

BASE = "https://www.haydnkino.at"
OVERVIEW = BASE + "/Cinema/Overview"
CURRENT_LIST = BASE + "/Cinema/CurrentList"
PREVIEW_LIST = BASE + "/Cinema/PreviewList"
VENUE = "Haydn Kino"
ADDRESS = "Mariahilferstraße 57, 1060 Wien"
DISTRICT = 1060
SOURCE = "haydnkino"

ENABLE_RE = re.compile(r"enable:\s*\[([^\]]*)\]")
DATE_STR_RE = re.compile(r"'(\d{4}-\d{2}-\d{2})'")

FILM_LINK_RE = re.compile(r'/Cinema/Movie\?filmId=(\d+)')
TITLE_RE = re.compile(r'<h2 class="movie-card__title">\s*<a[^>]*>\s*(.*?)\s*</a>', re.S)
SLOT_RE = re.compile(
    r'href="/Ticket/Reserve\?prgId=(\d+)&amp;screenId=(\d+)">(\d{1,2}):(\d{2})</a>\s*'
    r'</span>\s*<span[^>]*>\s*<span class="appendix">([^<]*)</span>', re.S)
STARTS_ON_RE = re.compile(r'movie-card__starts-on[^>]*>\s*Startet am\s*([^<]+)<', re.S)


def split_cards(html):
    parts = html.split('<div class="movie-card"')
    for part in parts[1:]:
        tm = re.match(r'\s*data-type="([^"]*)">', part)
        category = tm.group(1) if tm else None
        yield category, part


def parse_current(html):
    records = []
    for category, block in split_cards(html):
        fm = FILM_LINK_RE.search(block)
        if not fm:
            continue
        film_id = fm.group(1)
        url = f"{BASE}/Cinema/Movie?filmId={film_id}"
        tm = TITLE_RE.search(block)
        title = ea.text(tm.group(1)) if tm else None
        if not title:
            continue
        for prg_id, screen_id, hh, mm, appendix in SLOT_RE.findall(block):
            records.append({
                "prg_id": prg_id,
                "film_id": film_id,
                "url": url,
                "title": title,
                "category": category,
                "hh": hh,
                "mm": mm,
                "appendix": appendix.strip(),
            })
    return records


def parse_preview(html):
    records = []
    for category, block in split_cards(html):
        fm = FILM_LINK_RE.search(block)
        if not fm:
            continue
        film_id = fm.group(1)
        url = f"{BASE}/Cinema/Movie?filmId={film_id}"
        tm = TITLE_RE.search(block)
        title = ea.text(tm.group(1)) if tm else None
        if not title:
            continue
        sm = STARTS_ON_RE.search(block)
        if not sm:
            continue
        date = ea.de_date(sm.group(1))
        if not date:
            continue
        records.append({
            "film_id": film_id,
            "url": url,
            "title": title,
            "category": category,
            "date": date,
        })
    return records


def main():
    try:
        overview = ea.fetch(OVERVIEW, timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed overview: {e}\n")
        return

    try:
        today_sel = datetime.date.today().strftime("%d.%m.%Y")
        today_list = ea.fetch(f"{CURRENT_LIST}?dateSel={today_sel}", timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed CurrentList (today): {e}\n")
        today_list = ""

    em = ENABLE_RE.search(today_list) or ENABLE_RE.search(overview)
    dates = []
    if em:
        dates = DATE_STR_RE.findall(em.group(1))
    dates = sorted(set(dates))

    cutoff = ea.horizon()
    today = datetime.date.today()

    seen_film_ids = set()
    out = []
    for d in dates:
        y, mo, dd = (int(x) for x in d.split("-"))
        day = datetime.date(y, mo, dd)
        if day < today or day > cutoff:
            continue
        date_sel = day.strftime("%d.%m.%Y")
        if date_sel == datetime.date.today().strftime("%d.%m.%Y"):
            html = today_list
        else:
            try:
                html = ea.fetch(f"{CURRENT_LIST}?dateSel={date_sel}", timeout=60)
            except Exception as e:
                sys.stderr.write(f"fetch failed CurrentList {date_sel}: {e}\n")
                continue
        for rec in parse_current(html):
            seen_film_ids.add(rec["film_id"])
            start = f"{d}T{rec['hh'].zfill(2)}:{rec['mm']}"
            venue = f"{VENUE} (Saal {rec['appendix']})" if rec["appendix"] else VENUE
            out.append({
                "source": SOURCE,
                "source_id": rec["prg_id"],
                "url": rec["url"],
                "title": rec["title"],
                "start": start,
                "end": None,
                "venue": venue,
                "district": DISTRICT,
                "city": "Wien",
                "address": ADDRESS,
                "price_min": None,
                "price_text": None,
                "category": rec["category"],
                "description": None,
                "status": "scheduled",
            })

    try:
        preview_html = ea.fetch(PREVIEW_LIST, timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed PreviewList: {e}\n")
        preview_html = ""

    for rec in parse_preview(preview_html):
        if rec["film_id"] in seen_film_ids:
            continue
        date = rec["date"]
        date_only = date[:10]
        y, mo, dd = (int(x) for x in date_only.split("-"))
        day = datetime.date(y, mo, dd)
        if day < today or day > cutoff:
            continue
        out.append({
            "source": SOURCE,
            "source_id": f"{rec['film_id']}-{date_only}",
            "url": rec["url"],
            "title": rec["title"],
            "start": date,
            "end": None,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": rec["category"],
            "description": None,
            "status": "scheduled",
        })

    ea.emit(out)


if __name__ == "__main__":
    main()
