import datetime
import re
import sys

import ea

BASE = "https://www.filmcasino.at"
PAGES = [f"{BASE}/programm/?show=this", f"{BASE}/programm/?show=next"]

VENUES = {
    "Filmcasino": {"venue": "Filmcasino", "district": 1050,
                   "address": "Margaretenstraße 78, 1050 Wien"},
    "Filmhaus Spittelberg": {"venue": "Filmhaus Spittelberg", "district": 1070,
                              "address": "Spittelberggasse 3, 1070 Wien"},
}

ROW_RE = re.compile(
    r'<tr class=" [^"]*cinema\d[^"]*">\s*'
    r'<td><a href="([^"]+)">([^<]+)</a>'
    r'(?:<span class="disp-special"><a[^>]*>([^<]*)</a></span>)?</td>\s*'
    r'<td>(.*?)</td>\s*</tr>', re.S)

SHOW_RE = re.compile(r'data-show_id="(\d+)"[^>]*aria-label="Tickets ([^"]+)"')

LABEL_RE = re.compile(
    r'^(.+?) ([A-ZÄÖÜ][a-zäöüß]+) (\d{1,2})\.(\d{1,2})\. (\d{2}):(\d{2})$')


def resolve_year(month, day):
    today = datetime.date.today()
    y = today.year
    try:
        d = datetime.date(y, month, day)
    except ValueError:
        return None
    if (today - d).days > 30:
        y += 1
        d = datetime.date(y, month, day)
    return d


def parse_page(html, records, seen):
    for url, title, special, td in ROW_RE.findall(html):
        title = ea.text(title)
        special = ea.text(special)
        seen_ids = {}
        for sid, label in SHOW_RE.findall(td):
            seen_ids.setdefault(sid, label)
        for sid, label in seen_ids.items():
            if sid in seen:
                continue
            m = LABEL_RE.match(label)
            if not m:
                continue
            cinema, _weekday, day, month, hh, mm = m.groups()
            d = resolve_year(int(month), int(day))
            if not d:
                continue
            v = VENUES.get(cinema)
            if not v:
                continue
            seen.add(sid)
            records.append({
                "source": "filmcasino",
                "source_id": sid,
                "url": url,
                "title": title,
                "start": f"{d.isoformat()}T{hh}:{mm}",
                "end": None,
                "venue": v["venue"],
                "district": v["district"],
                "city": "Wien",
                "address": v["address"],
                "price_min": None,
                "price_text": None,
                "category": special,
                "description": None,
                "status": "scheduled",
            })


def main():
    cutoff = ea.horizon()
    records = []
    seen = set()
    for url in PAGES:
        try:
            html = ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"fetch failed for {url}: {e}\n")
            continue
        parse_page(html, records, seen)
    records = [r for r in records if r["start"][:10] <= cutoff.isoformat()]
    ea.emit(records)


if __name__ == "__main__":
    main()
