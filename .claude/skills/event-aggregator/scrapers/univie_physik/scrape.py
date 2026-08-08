import re
import sys
import time
import urllib.parse

import ea

BASE = "https://physik.univie.ac.at"
URL = BASE + "/events/"

ITEM_RE = re.compile(
    r'<div class="col-md-4 col-sm-6 news-box article.*?</div>\s*<!-- RENDER -->',
    re.S)
LINK_RE = re.compile(r'<a[^>]+title="([^"]+)"\s+(?:target="_blank"\s+)?'
                     r'href="([^"]+)"')
IMG_RE = re.compile(r'<img[^>]+src="([^"]+)"')
TEASER_RE = re.compile(r'itemprop="description">(.*?)</span>', re.S)

MONTHS = {
    "januar": 1, "february": 2, "februar": 2, "march": 3, "märz": 3,
    "april": 4, "may": 5, "mai": 5, "june": 6, "juni": 6, "july": 7,
    "juli": 7, "august": 8, "september": 9, "october": 10, "oktober": 10,
    "november": 11, "december": 12, "dezember": 12, "january": 1,
}

RANGE_RE = re.compile(
    r'(\d{1,2})\.\s*(?:[A-Za-zÀ-ÿ]+)?\s*[-–]\s*[A-Za-zÀ-ÿ]+,\s*'
    r'(\d{1,2})\.\s*([A-Za-zÀ-ÿ]+)\s*(\d{4})')
SINGLE_RE = re.compile(
    r'(\d{1,2})\.(\d{1,2})\.(\d{4})(?:,\s*(\d{1,2}):(\d{2}))?')


def fetch_retry(url, attempts=8):
    for i in range(attempts):
        try:
            return ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"{url} attempt {i + 1}: {e}\n")
            time.sleep(3)
    return None


def parse_dates(first_para):
    m = RANGE_RE.search(first_para)
    if m:
        d1, d2, mon, year = m.groups()
        mo = MONTHS.get(mon.lower())
        if mo:
            start = f"{year}-{mo:02d}-{int(d1):02d}"
            end = f"{year}-{mo:02d}-{int(d2):02d}"
            return start, end
    m = SINGLE_RE.search(first_para)
    if m:
        d, mo, y, hh, mm = m.groups()
        start = f"{y}-{int(mo):02d}-{int(d):02d}"
        if hh:
            start += f"T{int(hh):02d}:{mm}"
        return start, None
    return None, None


def parse_item(block):
    m = LINK_RE.search(block)
    if not m:
        return None
    title, href = m.groups()
    title = ea.text(title)
    url = urllib.parse.urljoin(BASE, href)

    m = IMG_RE.search(block)
    image = urllib.parse.urljoin(BASE, m.group(1)) if m else None

    m = TEASER_RE.search(block)
    teaser_html = m.group(1) if m else ""
    paras = [ea.text(p) for p in re.findall(r'<p>(.*?)</p>', teaser_html, re.S)]
    paras = [p for p in paras if p]

    if not paras:
        return None

    start, end = parse_dates(paras[0])
    if not start:
        return None

    venue = None
    category = None
    for p in paras[1:]:
        if p.lower().startswith("event from"):
            category = p[len("event from"):].strip(" :")
        elif p.lower().startswith("ort:"):
            venue = p[len("ort:"):].strip()
        elif venue is None:
            venue = p

    district = ea.district(venue)
    source_id = href.rstrip("/").rsplit("/", 1)[-1] or href

    return {
        "source": "univie_physik",
        "source_id": source_id,
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": district,
        "city": None,
        "address": None,
        "price_min": None,
        "price_text": None,
        "category": category,
        "description": None,
        "image": image,
        "extra": None,
    }


def main():
    page = fetch_retry(URL)
    recs = []
    if page:
        horizon = ea.horizon().isoformat()
        for block in ITEM_RE.findall(page):
            rec = parse_item(block)
            if rec and rec["start"][:10] <= horizon:
                recs.append(rec)
    ea.emit(recs)


if __name__ == "__main__":
    main()
