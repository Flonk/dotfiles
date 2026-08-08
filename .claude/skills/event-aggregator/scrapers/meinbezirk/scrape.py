import datetime
import re
import sys
import time
import urllib.error
import urllib.parse

import ea

BASE = "https://www.meinbezirk.at"
LIST_PATH = "/event/wien/list/all/{page}"

DISTRICTS = {
    "innere-stadt": 1010,
    "leopoldstadt": 1020,
    "landstrasse": 1030,
    "wieden": 1040,
    "margareten": 1050,
    "mariahilf": 1060,
    "neubau": 1070,
    "josefstadt": 1080,
    "alsergrund": 1090,
    "favoriten": 1100,
    "simmering": 1110,
    "meidling": 1120,
    "hietzing": 1130,
    "penzing": 1140,
    "rudolfsheim-fuenfhaus": 1150,
    "ottakring": 1160,
    "hernals": 1170,
    "waehring": 1180,
    "doebling": 1190,
    "brigittenau": 1200,
    "floridsdorf": 1210,
    "donaustadt": 1220,
    "liesing": 1230,
}

CATEGORIES = {
    "ausstellung": "Ausstellung",
    "ball-fest": "Ball/Fest",
    "brauchtum-kultur": "Brauchtum/Kultur",
    "gesundheit": "Gesundheit",
    "kinder-jugend": "Kinder/Jugend",
    "konzert-buehne-kino": "Konzert/Bühne/Kino",
    "kulinarik": "Kulinarik",
    "literatur-buch": "Literatur/Buch",
    "markt-basar": "Markt/Basar",
    "sonstiges": "Sonstiges",
    "sport": "Sport",
    "workshop-seminar-infoveranstaltung": "Workshop/Seminar/Infoveranstaltung",
}

ART_RE = re.compile(
    r'<article class="content-list-item content-card '
    r'(content-card-default|content-card-listview)" data-eventitem-id="(\d+)">'
    r'(.*?)</article>', re.S)
TITLE_RE = re.compile(r'<h3[^>]*>\s*<a href="([^"]+)"[^>]*>(.*?)</a>\s*</h3>', re.S)
DATELOC_RE = re.compile(r'<ul class="content-card-date-location">(.*?)</ul>', re.S)
LI_RE = re.compile(r'<li>(.*?)</li>', re.S)
DESC_RE = re.compile(r'<div class="content-card-text">.*?<p[^>]*>(.*?)</p>', re.S)
PATH_RE = re.compile(r'^/event/([a-z0-9-]+)/(?:c-([a-z0-9-]+)/)?[a-z0-9-]+_e\d+')
FREE_RE = re.compile(
    r'eintritt[^.]{0,15}(?:frei|kostenlos|gratis)'
    r'|(?:freier|gratis|kostenloser)[ -]eintritt'
    r'|veranstaltung ist (?:kostenlos|gratis)', re.I)


def parse_page(page, seen):
    records = []
    for m in ART_RE.finditer(page):
        eid = m.group(2)
        if eid in seen:
            continue
        seen.add(eid)
        block = m.group(3)

        tm = TITLE_RE.search(block)
        if not tm:
            continue
        href, title_html = tm.group(1), tm.group(2)
        title = ea.text(title_html)
        if not title:
            continue

        dl = DATELOC_RE.search(block)
        if not dl:
            continue
        lis = [ea.text(li) for li in LI_RE.findall(dl.group(1))]
        if not lis or not lis[0]:
            continue
        start = ea.de_date(lis[0])
        if not start:
            continue
        venue = lis[1] if len(lis) >= 3 else None

        pm = PATH_RE.match(href)
        district = None
        category = None
        if pm:
            dslug, cslug = pm.group(1), pm.group(2)
            district = DISTRICTS.get(dslug)
            if cslug:
                category = CATEGORIES.get(cslug, cslug)

        desc_m = DESC_RE.search(block)
        description = ea.text(desc_m.group(1)) if desc_m else None

        price_min = price_text = None
        if description and FREE_RE.search(description):
            price_min, price_text = 0.0, "Eintritt frei"

        records.append({
            "source": "meinbezirk",
            "source_id": eid,
            "url": BASE + href,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": district,
            "city": "Wien",
            "address": None,
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
            "description": description,
            "status": "scheduled",
        })
    return records


def main():
    today = datetime.date.today()
    end = ea.horizon()
    qs = urllib.parse.urlencode({
        "eventitem_filter_simple[date_start]": today.isoformat(),
        "eventitem_filter_simple[date_end]": end.isoformat(),
    })

    seen = set()
    all_records = []
    page = 1
    max_pages = 90
    while page <= max_pages:
        url = f"{BASE}{LIST_PATH.format(page=page)}?{qs}"
        html = None
        for attempt in range(3):
            try:
                html = ea.fetch(url)
                break
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    html = ""
                    break
                sys.stderr.write(f"page {page} attempt {attempt}: {e}\n")
                time.sleep(1)
            except Exception as e:
                sys.stderr.write(f"page {page} attempt {attempt}: {e}\n")
                time.sleep(1)
        if html is None:
            sys.stderr.write(f"stop at page {page}: repeated fetch failures\n")
            break
        if html == "":
            break
        recs = parse_page(html, seen)
        all_records.extend(recs)
        page += 1

    ea.emit(all_records)


if __name__ == "__main__":
    main()
