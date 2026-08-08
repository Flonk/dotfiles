import datetime
import re
import sys

import ea

BASE = "https://www.nhm.at"
LIST_URL = BASE + "/veranstaltungskalender"

VENUE_INFO = {
    "NHM Wien": ("Maria-Theresien-Platz", 1010),
    "Narrenturm": ("Spitalgasse 2", 1090),
}

TOTAL_RE = re.compile(r"(\d+)-(\d+) von (\d+) Terminen")
DATE_RE = re.compile(r'termin__date--liste">\s*(\d{1,2})\.(\d{1,2})\.')
TIME_RE = re.compile(r'termin__time--liste">\s*(\d{1,2}):(\d{2})\s*&ndash;\s*(\d{1,2}):(\d{2})')
TITLE_RE = re.compile(r'<a href="(/veranstaltungskalender/[^"]+)">(.*?)</a>')
DESC_RE = re.compile(r'termin__info--liste">\s*<p>(.*?)</p>', re.S)
VENUE_RE = re.compile(r'order-3 order-lg-1 mb-2 ml-lg-0 ml-auto">\s*([^<]+?)\s*</div>')


def month_url(year, month, page):
    return (f"{LIST_URL}?datum_von={year:04d}-{month:02d}-01"
            f"&dateMode=month&page={page}")


def parse_page(html, year):
    total_m = TOTAL_RE.search(html)
    total = int(total_m.group(3)) if total_m else None
    recs = []
    blocks = html.split('class="grid grid--termin')[1:]
    for b in blocks:
        dm = DATE_RE.search(b)
        tm = TIME_RE.search(b)
        ttl = TITLE_RE.search(b)
        if not (dm and ttl):
            continue
        day, month = int(dm.group(1)), int(dm.group(2))
        try:
            date = datetime.date(year, month, day)
        except ValueError:
            continue
        start = f"{date.isoformat()}"
        end = None
        if tm:
            start = f"{date.isoformat()}T{int(tm.group(1)):02d}:{tm.group(2)}"
            end = f"{date.isoformat()}T{int(tm.group(3)):02d}:{tm.group(4)}"
        href, title_html = ttl.groups()
        title = ea.text(title_html)
        if not title:
            continue
        slug = href.rsplit("/", 1)[-1]
        url = BASE + href
        dscm = DESC_RE.search(b)
        description = ea.text(dscm.group(1)) if dscm else None
        vm = VENUE_RE.search(b)
        venue = ea.text(vm.group(1)) if vm else None
        address, dist = VENUE_INFO.get(venue, (None, None))
        city = "Wien" if venue in VENUE_INFO else venue
        source_id = f"{slug}_{start}"
        recs.append({
            "source": "nhm_events",
            "source_id": source_id,
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
            "category": venue,
            "description": description,
            "status": "scheduled",
        })
    return recs, total


def main():
    cutoff = ea.horizon()
    today = datetime.date.today()
    year, month = today.year, today.month
    out = []
    empty_months = 0
    for _ in range(24):
        month_start = datetime.date(year, month, 1)
        if month_start > cutoff:
            break
        page = 1
        month_had_events = False
        while True:
            html = ea.fetch(month_url(year, month, page))
            recs, total = parse_page(html, year)
            if not recs:
                break
            month_had_events = True
            out.extend(recs)
            if total is not None and page * 20 >= total:
                break
            if len(recs) < 20:
                break
            page += 1
        empty_months = 0 if month_had_events else empty_months + 1
        if empty_months >= 2:
            break
        month += 1
        if month > 12:
            month = 1
            year += 1

    ea.emit(out)


if __name__ == "__main__":
    main()
