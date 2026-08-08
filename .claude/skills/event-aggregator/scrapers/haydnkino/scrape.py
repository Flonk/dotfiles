import datetime
import re
import sys
from concurrent.futures import ThreadPoolExecutor

import ea

BASE = "https://www.haydnkino.at"
OVERVIEW = BASE + "/Cinema/Overview"
CURRENT_LIST = BASE + "/Cinema/CurrentList"
PREVIEW_LIST = BASE + "/Cinema/PreviewList"
VENUE = "Haydn Kino"
ADDRESS = "Mariahilferstraße 57, 1060 Wien"
DISTRICT = 1060
SOURCE = "haydnkino"
FETCH_TIMEOUT = 30

ENABLE_RE = re.compile(r"enable:\s*\[([^\]]*)\]")
DATE_STR_RE = re.compile(r"'(\d{4}-\d{2}-\d{2})'")

FILM_LINK_RE = re.compile(r'/Cinema/Movie\?filmId=(\d+)')
TITLE_RE = re.compile(r'<h2 class="movie-card__title">\s*<a[^>]*>\s*(.*?)\s*</a>', re.S)
SLOT_RE = re.compile(
    r'href="/Ticket/Reserve\?prgId=(\d+)&amp;screenId=(\d+)">(\d{1,2}):(\d{2})</a>\s*'
    r'</span>\s*<span[^>]*>\s*<span class="appendix">([^<]*)</span>', re.S)
STARTS_ON_RE = re.compile(r'movie-card__starts-on[^>]*>\s*Startet am\s*([^<]+)<', re.S)

DETAIL_IMAGE_RE = re.compile(r'<img src="(/FilmImg/[^"]+)"')
DETAIL_HEADER_RE = re.compile(
    r'<div class="movie-detail__header.*?<p>\s*(.*?)\s*</p>', re.S)


def fetch_with_retry(url, timeout=FETCH_TIMEOUT, tries=2):
    last = None
    for _ in range(tries):
        try:
            return ea.fetch(url, timeout=timeout)
        except Exception as e:
            last = e
    sys.stderr.write(f"fetch failed {url}: {last}\n")
    return None


def fetch_detail(url):
    html = fetch_with_retry(url)
    if not html:
        return None, None
    im = DETAIL_IMAGE_RE.search(html)
    image = BASE + im.group(1) if im else None
    hm = DETAIL_HEADER_RE.search(html)
    origin_year_runtime = ea.text(hm.group(1)) if hm else None
    return image, origin_year_runtime


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


def fetch_current_list(date_sel):
    html = fetch_with_retry(f"{CURRENT_LIST}?dateSel={date_sel}")
    return date_sel, html or ""


def main():
    try:
        overview = ea.fetch(OVERVIEW, timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed overview: {e}\n")
        return

    today_sel = datetime.date.today().strftime("%d.%m.%Y")
    _, today_list = fetch_current_list(today_sel)

    em = ENABLE_RE.search(today_list) or ENABLE_RE.search(overview)
    dates = []
    if em:
        dates = DATE_STR_RE.findall(em.group(1))
    dates = sorted(set(dates))

    cutoff = ea.horizon()
    today = datetime.date.today()

    wanted = []
    for d in dates:
        y, mo, dd = (int(x) for x in d.split("-"))
        day = datetime.date(y, mo, dd)
        if day < today or day > cutoff:
            continue
        wanted.append((d, day.strftime("%d.%m.%Y")))

    date_html = {today_sel: today_list}
    to_fetch = [date_sel for _, date_sel in wanted if date_sel not in date_html]
    with ThreadPoolExecutor(max_workers=6) as ex:
        for date_sel, html in ex.map(fetch_current_list, to_fetch):
            date_html[date_sel] = html

    seen_film_ids = set()
    out = []
    for d, date_sel in wanted:
        html = date_html.get(date_sel, "")
        if not html:
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

    urls = sorted({r["url"] for r in out})
    details = {}
    with ThreadPoolExecutor(max_workers=6) as ex:
        for url, result in zip(urls, ex.map(fetch_detail, urls)):
            details[url] = result
    for r in out:
        image, origin_year_runtime = details.get(r["url"], (None, None))
        r["image"] = image
        if origin_year_runtime:
            r["extra"] = {"origin_year_runtime": origin_year_runtime}

    ea.emit(out)


if __name__ == "__main__":
    main()
