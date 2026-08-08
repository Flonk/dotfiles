import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import ea

BASE = "https://www.vetmeduni.ac.at"
LIST = BASE + "/universitaet/infoservice/veranstaltungen"

LINK_RE = re.compile(
    r'href="(/universitaet/infoservice/veranstaltungen/detail/[^"]+)"')


def fetch_retry(url, attempts=8):
    for i in range(attempts):
        try:
            return ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"{url} attempt {i + 1}: {e}\n")
            time.sleep(3)
    return None


def list_page(n):
    url = LIST if n == 1 else f"{LIST}/page-{n}"
    return fetch_retry(url)


def collect_links():
    links = []
    seen = set()
    n = 1
    while n <= 40:
        page = list_page(n)
        if not page:
            break
        found = list(dict.fromkeys(LINK_RE.findall(page)))
        new = [f for f in found if f not in seen]
        if not found:
            break
        seen.update(found)
        links.extend(new)
        dates = [d for d in re.findall(r'datetime="(\d{4}-\d{2}-\d{2})"', page)]
        if dates and dates[-1] > ea.horizon().isoformat():
            break
        if not new:
            break
        n += 1
    return links


def parse_detail(path):
    url = BASE + path
    page = fetch_retry(url)
    if not page:
        return None

    m = re.search(r'<h1 class="news-header-headline[^"]*">(.*?)</h1>', page, re.S)
    title = ea.text(m.group(1)) if m else None
    if not title:
        return None

    m = re.search(r'Ort:\s*([^<]+)', page)
    venue_raw = ea.text(m.group(1)) if m else None
    if venue_raw:
        venue_raw = venue_raw.rstrip(", ").strip() or None

    m = re.search(r'Veranstaltungsbeginn:</strong>\s*([^<]+)', page)
    start = ea.de_date(m.group(1)) if m else None
    if not start:
        m = re.search(r'<time itemprop="datePublished" datetime="([^"]+)"', page)
        start = m.group(1) if m else None

    m = re.search(r'Veranstaltungsende:</strong>\s*([^<]+)', page)
    end = ea.de_date(m.group(1)) if m else None

    m = re.search(r'Veranstaltungskategorie:\s*</strong>\s*<span[^>]*>(.*?)</span>',
                  page, re.S)
    category = ea.text(m.group(1)) if m else None

    m = re.search(r'<div class="news-bodytext[^"]*">(.*?)</div>\s*</div>\s*</div>',
                  page, re.S)
    description = ea.text(m.group(1))[:600] if m else None

    m = re.search(r'itemprop="image"[^>]*src="([^"]+)"', page)
    image = BASE + m.group(1) if m and m.group(1).startswith("/") else None

    price_min, price_text = None, None
    m = re.search(r'(kostenlos|Eintritt frei|gratis)', page, re.I)
    if m:
        price_min, price_text = 0.0, m.group(1)

    district = ea.district(venue_raw)

    if not start:
        return None

    return {
        "source": "vetmeduni",
        "source_id": path.rsplit("/", 1)[-1],
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue_raw,
        "district": district,
        "city": None,
        "address": venue_raw,
        "price_min": price_min,
        "price_text": price_text,
        "category": category,
        "description": description,
        "image": image,
        "extra": None,
    }


def main():
    links = collect_links()
    recs = []
    with ThreadPoolExecutor(max_workers=8) as ex:
        for r in ex.map(parse_detail, links):
            if r:
                recs.append(r)
    ea.emit(recs)


if __name__ == "__main__":
    main()
