import datetime
import re
import sys
import time
import urllib.parse
from concurrent.futures import ThreadPoolExecutor

import ea

BASE = "https://www.ait.ac.at"
API = BASE + "/index.php"

MONTHS = {
    "Januar": 1, "Februar": 2, "März": 3, "April": 4, "Mai": 5, "Juni": 6,
    "Juli": 7, "August": 8, "September": 9, "Oktober": 10, "November": 11,
    "Dezember": 12,
}

TEASER_RE = re.compile(
    r'<div class="feature-wrap news[^"]*" data-date="(\d+)" data-uid="(\d+)">'
    r'.*?href="([^"]+)".*?'
    r'<span class="d">([^<]+)</span>.*?'
    r'(<abbr title="[^"]+">[^<]+</abbr>(?:-<abbr title="[^"]+">[^<]+</abbr>)?)'
    r'.*?<h2[^>]*>\s*([^<]+?)\s*</h2>',
    re.S)

ABBR_RE = re.compile(r'<abbr title="([^"]+)">')


def fetch_retry(url, attempts=8, **kw):
    for i in range(attempts):
        try:
            return ea.fetch(url, **kw)
        except Exception as e:
            sys.stderr.write(f"{url} attempt {i + 1}: {e}\n")
            time.sleep(3)
    return None


def list_events():
    params = {
        "id": "2580",
        "tx_aitnewsfeatures_newsapi[amount]": "100",
        "tx_aitnewsfeatures_newsapi[last]": "0",
        "tx_aitnewsfeatures_newsapi[uid]": "0",
        "tx_aitnewsfeatures_newsapi[show]": "events",
        "tx_aitnewsfeatures_newsapi[archive]": "0",
        "tx_aitnewsfeatures_newsapi[searchDateFrom]": "01.01.1980",
        "tx_aitnewsfeatures_newsapi[searchDateTo]": "31.12.2199",
        "L": "0",
    }
    url = API + "?" + urllib.parse.urlencode(params)
    page = fetch_retry(url)
    if not page:
        return []

    items = []
    for m in TEASER_RE.finditer(page):
        ts, uid, href, day_txt, month_html, title = m.groups()
        months = ABBR_RE.findall(month_html)
        end_dt = datetime.datetime.utcfromtimestamp(int(ts))
        day_txt = day_txt.strip()
        if "-" in day_txt:
            d1, d2 = day_txt.split("-")
            m1 = months[0]
            m2 = months[-1]
            end_year = end_dt.year
            start_year = end_year
            if MONTHS[m1] > MONTHS[m2]:
                start_year -= 1
            start = f"{start_year:04d}-{MONTHS[m1]:02d}-{int(d1):02d}"
            end = f"{end_year:04d}-{MONTHS[m2]:02d}-{int(d2):02d}"
        else:
            start = end = (f"{end_dt.year:04d}-{MONTHS[months[0]]:02d}"
                            f"-{int(day_txt):02d}")
        items.append({
            "uid": uid,
            "url": urllib.parse.urljoin(BASE, html_unescape(href)),
            "title": ea.text(title),
            "start": start,
            "end": end,
        })
    return items


def html_unescape(s):
    import html
    return html.unescape(s)


def enrich(item):
    page = fetch_retry(item["url"])
    if not page:
        return item

    start, end, venue = item["start"], item["end"], None

    m = re.search(r'Datum:</strong>\s*(?:[A-Za-zäöüß]+,\s*)?'
                  r'(\d{1,2}\.\s*[A-Za-zäöüß]+\s*\d{4})', page)
    if m:
        d = ea.de_date(m.group(1))
        if d:
            start = d
            if not item["end"] or item["end"] < d:
                end = d

    m = re.search(r'(\d{1,2}[:.]\d{2})\s*(?:[-–]\s*\d{1,2}[:.]\d{2})?\s*Uhr', page)
    if m and re.match(r"^\d{4}-\d{2}-\d{2}$", start):
        hh, mm = re.split(r"[:.]", m.group(1))
        start = f"{start}T{int(hh):02d}:{mm}"

    m = re.search(r'Ort:</strong>\s*([^<\n]+)', page)
    if m:
        venue = ea.text(m.group(1))
    if not venue:
        m = re.search(r'Veranstaltungsort</strong></p>\s*<p>.*?im\s*'
                      r'<strong>([^<]+)</strong>', page, re.S)
        if m:
            venue = ea.text(m.group(1))
    if not venue:
        m = re.search(r'\d{4}\s+in\s+([^,<]+,\s*[^,<]+?)(?:</strong>)?,\s*statt', page)
        if m:
            venue = ea.text(m.group(1))

    district = ea.district(venue)

    m = re.search(r'<h1[^>]*>\s*([^<]+?)\s*</h1>', page)
    title = ea.text(m.group(1)) if m else item["title"]

    item.update({
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": district,
    })
    return item


def main():
    items = list_events()
    horizon = ea.horizon().isoformat()
    items = [i for i in items if i["start"][:10] <= horizon]

    recs = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        for it in ex.map(enrich, items):
            recs.append({
                "source": "ait",
                "source_id": it["uid"],
                "url": it["url"],
                "title": it["title"],
                "start": it["start"],
                "end": it.get("end"),
                "venue": it.get("venue"),
                "district": it.get("district"),
                "city": None,
                "address": None,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": None,
                "image": None,
                "extra": None,
            })
    ea.emit(recs)


if __name__ == "__main__":
    main()
