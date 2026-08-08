import datetime
import os
import re
import sys
import urllib.error

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

LIST_URL = "https://www.ottakringerbrauerei.at/de/events-locations/eventkalender/"

ARTICLE_RE = re.compile(r"<article aria-labelledby=.*?</article>", re.S)
TITLE_RE = re.compile(r'event-calendar-item__title[^>]*>\s*(.*?)\s*</div>', re.S)
HREF_RE = re.compile(r'href="(https://www\.ottakringerbrauerei\.at/de/event/[^"]+)"')
TIME_TEXT_RE = re.compile(r'event-calendar-item__time[^"]*"[^>]*>.*?text-ellipsis">([^<]*)</span>', re.S)
UPTITLE_RE = re.compile(r'event-detail__uptitle[^>]*>\s*([0-9.\- ]+?)\s*</div>')
DESC_RE = re.compile(
    r'<div class="event-detail__text copy">(.*?)<div class="event-detail__(?:ticket_button|share)"',
    re.S,
)


def parse_times(s):
    if not s:
        return None, None
    hh = re.findall(r"(\d{1,2}):(\d{2})", s)
    if not hh:
        return None, None
    t0 = f"{int(hh[0][0]):02d}:{hh[0][1]}"
    t1 = f"{int(hh[1][0]):02d}:{hh[1][1]}" if len(hh) > 1 else None
    return t0, t1


def parse_uptitle(page):
    m = UPTITLE_RE.search(page)
    if not m:
        return None, None
    raw = m.group(1).strip()
    parts = [p.strip() for p in raw.split("-")]
    dates = []
    for p in parts:
        dm = re.match(r"(\d{2})\.(\d{2})\.(\d{4})", p)
        if not dm:
            return None, None
        d, mo, y = dm.groups()
        dates.append(f"{y}-{mo}-{d}")
    if len(dates) == 1:
        return dates[0], None
    return dates[0], dates[1]


def parse_description(page):
    m = DESC_RE.search(page)
    if not m:
        return None
    return ea.text(m.group(1))


def main():
    page = ea.fetch(LIST_URL)
    cutoff = ea.horizon()

    seen = set()
    records = []
    for art in ARTICLE_RE.findall(page):
        tm = TITLE_RE.search(art)
        hm = HREF_RE.search(art)
        if not tm or not hm:
            continue
        title = ea.text(tm.group(1))
        url = hm.group(1)
        if url in seen:
            continue
        seen.add(url)

        time_m = TIME_TEXT_RE.search(art)
        t0, t1 = parse_times(time_m.group(1) if time_m else None)

        try:
            detail = ea.fetch(url)
        except (urllib.error.URLError, urllib.error.HTTPError):
            continue

        start_date, end_date = parse_uptitle(detail)
        if not start_date:
            continue

        start = f"{start_date}T{t0}" if t0 else start_date
        end = None
        if end_date:
            end = f"{end_date}T{t1}" if t1 else end_date
        elif t1:
            end_day = start_date
            if t0 and t1 <= t0:
                nd = datetime.date.fromisoformat(start_date) + datetime.timedelta(days=1)
                end_day = nd.isoformat()
            end = f"{end_day}T{t1}"

        try:
            cutoff_date = datetime.date.fromisoformat(start_date)
        except ValueError:
            cutoff_date = None
        if cutoff_date and cutoff_date > cutoff:
            continue

        records.append({
            "source": "ottakringerbrauerei",
            "source_id": url,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": "Ottakringer Brauerei",
            "district": 1160,
            "city": "Wien",
            "address": None,
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": parse_description(detail),
            "status": "scheduled",
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
