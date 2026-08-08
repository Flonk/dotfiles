import html
import re

import ea

BASE = "https://www.volkskundemuseum.at"
TERMINE_URL = BASE + "/termine"
AKTUELL_URL = BASE + "/programm/aktuell"

CATEGORY_IDS = {
    "1590410545289": "Führung",
    "1590410545291": "Kinderprogramm",
    "1590410545295": "Exkursion",
    "1590410545310": "Vorteile für Vereinsmitglieder",
    "1747168207620": "Musik / Theater / Performance",
    "1590410545293": "Diskussion / Vortrag / Tagung",
    "1747168207629": "Workshop",
    "1732226839624": "Hof der Kulturen",
    "1778707236082": "toxic dreams",
}

VENUE_INFO = [
    ("Pavillon 1 @ Otto Wagner Areal", ("Volkskundemuseum am Otto Wagner Areal, Pavillon 1", "Baumgartner Höhe 1", 1140)),
    ("Otto Wagner Areal", ("Volkskundemuseum am Otto Wagner Areal", "Baumgartner Höhe 1", 1140)),
    ("Schönbornpark", ("Schönbornpark", "Laudongasse 15-19", 1080)),
]

TEASER_START = re.compile(r'<div class="teaser-element-holder')
DBID_RE = re.compile(r'dbid_(\d+)')
H3_RE = re.compile(r'<h3 class="title"><a[^>]*href="([^"]+)"[^>]*>(.*?)</a></h3>', re.S)
H4_RE = re.compile(r'<h4 class="subtitle"><a[^>]*href="([^"]+)"[^>]*>(.*?)</a></h4>', re.S)
SUBTITLE_INFO_RE = re.compile(r'class="subtitle-info">([^<]*)</a>')
DATE_RE = re.compile(r'class="date">([^<]*)</div>')
TEXT_RE = re.compile(r'class="teaser-element-text">(.*?)<a class="more_link"', re.S)


def split_teasers(page):
    idxs = [m.start() for m in TEASER_START.finditer(page)]
    idxs.append(len(page))
    return [page[idxs[i]:idxs[i + 1]] for i in range(len(idxs) - 1)]


def parse_daterange(raw):
    s = html.unescape(raw).strip()
    parts = re.split(r'\s*[–-]\s*', s)

    def parse_one(p, carry_date=None):
        p = re.sub(r'^[A-Za-zÄÖÜäöü]{2},\s*', '', p).strip()
        dm = re.search(r'(\d{2})\.(\d{2})\.(\d{4})', p)
        tm = re.search(r'(\d{2}):(\d{2})', p)
        date = f"{dm.group(3)}-{dm.group(2)}-{dm.group(1)}" if dm else carry_date
        if date and tm:
            return f"{date}T{tm.group(1)}:{tm.group(2)}"
        return date

    start = parse_one(parts[0])
    end = None
    if len(parts) > 1 and start:
        end = parse_one(parts[1], carry_date=start[:10])
    return start, end


def venue_lookup(venue):
    if not venue:
        return None, None, None
    for key, info in VENUE_INFO:
        if key in venue:
            return info
    return venue, None, None


def category_map():
    m = {}
    for cid, label in CATEGORY_IDS.items():
        page = ea.fetch(f"{TERMINE_URL}?article_category_id={cid}")
        for did in DBID_RE.findall(page):
            m.setdefault(did, label)
    return m


def parse_teaser(chunk):
    dm = DBID_RE.search(chunk)
    if not dm:
        return None
    h3 = H3_RE.search(chunk)
    h4 = H4_RE.search(chunk)
    if h3:
        href, title_html = h3.groups()
    elif h4:
        href, title_html = h4.groups()
    else:
        return None
    title = ea.text(title_html)
    if not title:
        return None
    date_m = DATE_RE.search(chunk)
    if not date_m:
        return None
    start, end = parse_daterange(date_m.group(1))
    if not start:
        return None
    sub_m = SUBTITLE_INFO_RE.search(chunk)
    subtitle_info = ea.text(sub_m.group(1)) if sub_m else None
    text_m = TEXT_RE.search(chunk)
    description = ea.text(text_m.group(1)) if text_m else None
    url = BASE + href if href.startswith("/") else href
    return {
        "dbid": dm.group(1),
        "source_id": href.lstrip("/"),
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue_raw": subtitle_info,
        "description": description,
    }


def termine_records():
    page = ea.fetch(TERMINE_URL)
    cats = category_map()
    cutoff = ea.horizon()
    out = []
    for chunk in split_teasers(page):
        rec = parse_teaser(chunk)
        if not rec:
            continue
        start_date = rec["start"][:10]
        import datetime
        if datetime.date.fromisoformat(start_date) > cutoff:
            continue
        venue, address, district = venue_lookup(rec["venue_raw"])
        out.append({
            "source": "volkskundemuseum",
            "source_id": rec["source_id"],
            "url": rec["url"],
            "title": rec["title"],
            "start": rec["start"],
            "end": rec["end"],
            "venue": venue,
            "district": district,
            "city": "Wien",
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": cats.get(rec["dbid"]),
            "description": rec["description"],
            "status": "scheduled",
        })
    return out


def aktuell_records():
    page = ea.fetch(AKTUELL_URL)
    out = []
    for chunk in split_teasers(page):
        rec = parse_teaser(chunk)
        if not rec:
            continue
        # subtitle-info on this page is a tag (e.g. "Pilotprojekt"), not a
        # location; all current programming runs at the Otto Wagner Areal
        # while the Laudongasse building is closed for renovation.
        venue, address, district = ("Volkskundemuseum am Otto Wagner Areal",
                                     "Baumgartner Höhe 1", 1140)
        end = rec["end"]
        extra = {}
        if not end:
            extra["permanent"] = True
        out.append({
            "source": "volkskundemuseum",
            "source_id": rec["source_id"],
            "url": rec["url"],
            "title": rec["title"],
            "start": rec["start"],
            "end": end,
            "venue": venue,
            "district": district,
            "city": "Wien",
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": "Ausstellung",
            "description": rec["description"],
            "status": "scheduled",
            "extra": extra or None,
        })
    return out


def meet_otto_record():
    url = BASE + "/ausstellung/meet_otto"
    page = ea.fetch(url)
    m = re.search(r'avtext-container"><span class="avtext">Seit\s*(\d{2})\.(\d{2})\.(\d{4})</span>', page)
    if not m:
        return None
    d, mo, y = m.groups()
    start = f"{y}-{mo}-{d}"
    return {
        "source": "volkskundemuseum",
        "source_id": "ausstellung/meet_otto",
        "url": url,
        "title": "MEET OTTO",
        "start": start,
        "end": None,
        "venue": "Volkskundemuseum am Otto Wagner Areal, Pavillon 1",
        "district": 1140,
        "city": "Wien",
        "address": "Baumgartner Höhe 1",
        "price_min": 0.0,
        "price_text": "Eintritt frei",
        "category": "Ausstellung",
        "description": ea.text(
            "Ziel der Ausstellung ist es, die Transformation des Otto Wagner "
            "Areals darzustellen."),
        "status": "scheduled",
        "extra": {"permanent": True},
    }


def main():
    records = termine_records() + aktuell_records()
    mo = meet_otto_record()
    if mo:
        records.append(mo)
    ea.emit(records)


if __name__ == "__main__":
    main()
