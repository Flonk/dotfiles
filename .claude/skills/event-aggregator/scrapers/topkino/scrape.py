import datetime
import re
import sys

import ea

BASE = "https://www.topkino.at"
VENUE = "Top Kino"
ADDRESS = "Rahlgasse 1, 1060 Wien"
DISTRICT = 1060

LIST_PAGES = ["/kino/aktuell", "/kino/demnaechst"]

LINK_RE = re.compile(r'href="(/kino/(?:[a-z0-9_]+|veranstaltung_detail\?veranstaltung_id=\d+))"')
NAV_SLUGS = {
    "aktuell", "archiv", "demnaechst", "kinoprogramm", "rent_a_cinema",
    "schwerpunkte", "film_therapy_film_club", "fruehstueckskino_1",
}

TITLE_RE = re.compile(r'<h1 class="detail-titel">(.*?)</h1>', re.S)
SUBINFO_RE = re.compile(r'<div class="subinfo">\s*(.*?)</div>', re.S)
KURZ_RE = re.compile(r'<div class="kurzbeschreibung">(.*?)</div>\s*<div class="beschreibung">', re.S)
IMAGE_RE = re.compile(
    r'<div class="img-responsive"><img\s+alt="" src="([^"]+)"></div>\s*'
    r'<div class="kurzbeschreibung">', re.S)
TERMIN_RE = re.compile(
    r'<div class="termin">\s*<div class="datum">([^<]*)</div>\s*'
    r'<div class="raum">([^<]*)</div>.*?'
    r'data-termin_id="([^"]*)"',
    re.S)
FILMSTART_RE = re.compile(r'class="filmstart">\s*<a[^>]*>\s*([^<]*?)\s*</a>', re.S)


def gather_urls():
    urls = set()
    for path in LIST_PAGES:
        try:
            page = ea.fetch(BASE + path, timeout=60)
        except Exception as e:
            sys.stderr.write(f"fetch failed {path}: {e}\n")
            continue
        for href in LINK_RE.findall(page):
            slug_m = re.match(r"/kino/([a-z0-9_]+)$", href)
            if slug_m and slug_m.group(1) in NAV_SLUGS:
                continue
            urls.add(href)
    return sorted(urls)


def source_id_for(href):
    m = re.search(r"veranstaltung_id=(\d+)", href)
    if m:
        return m.group(1)
    return href.rsplit("/", 1)[-1]


def parse_detail(href):
    url = BASE + href
    try:
        page = ea.fetch(url, timeout=60)
    except Exception as e:
        sys.stderr.write(f"fetch failed {url}: {e}\n")
        return []

    tm = TITLE_RE.search(page)
    title = ea.text(tm.group(1)) if tm else None
    if not title:
        return []

    sm = SUBINFO_RE.search(page)
    subinfo = ea.text(sm.group(1)) if sm else None
    km = KURZ_RE.search(page)
    description = ea.text(km.group(1)) if km else None
    if description and subinfo:
        description = f"{subinfo} — {description}"
    elif subinfo:
        description = subinfo

    im = IMAGE_RE.search(page)
    image = BASE + im.group(1) if im else None
    extra = {"origin_year_runtime": subinfo} if subinfo else None

    records = []
    now = datetime.datetime.now()
    for datum, raum, termin_id in TERMIN_RE.findall(page):
        m = re.search(r"(\d{2})\.(\d{2})\.(\d{4})\s*\|\s*(\d{1,2}):(\d{2})", datum)
        if not m:
            continue
        dd, mo, yy, hh, mi = m.groups()
        start = f"{yy}-{mo}-{dd}T{hh.zfill(2)}:{mi}"
        try:
            start_dt = datetime.datetime(int(yy), int(mo), int(dd), int(hh), int(mi))
        except ValueError:
            continue
        if start_dt < now - datetime.timedelta(hours=3):
            continue
        raum = ea.text(raum)
        records.append({
            "source": "topkino",
            "source_id": termin_id or f"{source_id_for(href)}-{start}",
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "image": image,
            "venue": f"{VENUE} ({raum})" if raum else VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": description,
            "status": "scheduled",
            "extra": extra,
        })

    if not records:
        fm = FILMSTART_RE.search(page)
        if fm:
            d = ea.de_date(fm.group(1), default_year=datetime.date.today().year)
            if d:
                y, mo, dd = (int(x) for x in d[:10].split("-"))
                cand = datetime.date(y, mo, dd)
                if cand < datetime.date.today():
                    cand = cand.replace(year=cand.year + 1)
                records.append({
                    "source": "topkino",
                    "source_id": f"{source_id_for(href)}-start",
                    "url": url,
                    "title": title,
                    "start": cand.isoformat(),
                    "end": None,
                    "image": image,
                    "venue": VENUE,
                    "district": DISTRICT,
                    "city": "Wien",
                    "address": ADDRESS,
                    "price_min": None,
                    "price_text": None,
                    "category": None,
                    "description": description,
                    "status": "scheduled",
                    "extra": extra,
                })
    return records


def main():
    cutoff = ea.horizon()
    records = []
    for href in gather_urls():
        for rec in parse_detail(href):
            y, mo, d = (int(x) for x in rec["start"][:10].split("-"))
            if datetime.date(y, mo, d) > cutoff:
                continue
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
