import datetime
import html
import re

import ea

BASE = "https://www.albertina.at"
LISTING = "https://www.albertina.at/ausstellungen/"

H1_RE = re.compile(
    r'<h1 class="headline2[^"]*"[^>]*>([^<]*)</h1>\s*'
    r'(?:<h2 class="headline2[^"]*"[^>]*>([^<]*)</h2>)?')
SENT_RE = re.compile(
    r'ist von (.+?) bis (.+?)(?: in der [^<.]+)? zu sehen')


def find_links(listing_html):
    end = listing_html.find("Standorte")
    block = listing_html[:end] if end != -1 else listing_html
    start = block.find('id="aktuell"')
    block = block[start:] if start != -1 else block
    hrefs = []
    seen = set()
    for m in re.finditer(r'href="(/(?:ausstellungen|albertina-modern/ausstellungen)/[^"]+?)"', block):
        href = m.group(1).strip()
        if href in seen or href == "/ausstellungen/":
            continue
        seen.add(href)
        hrefs.append(href)
    return hrefs


def parse_detail(url, path):
    page = ea.fetch(url)
    m = H1_RE.search(page)
    if not m:
        return None
    title = html.unescape(m.group(1)).strip()
    subtitle = html.unescape(m.group(2)).strip() if m.group(2) else None
    if subtitle:
        title = f"{title} – {subtitle}"

    norm = page.replace("&nbsp;", " ")
    sm = SENT_RE.search(norm)
    if sm:
        end_txt = html.unescape(sm.group(2)).strip()
        end = ea.de_date(end_txt)
        default_year = end[:4] if end else None
        start_txt = html.unescape(sm.group(1)).strip()
        start = ea.de_date(start_txt, default_year=default_year)
    else:
        start = end = None

    if not start or not end:
        today = datetime.date.today()
        start = start or today.isoformat()
        end = end or (today + datetime.timedelta(days=3 * 365)).isoformat()

    venue = "Albertina Modern" if "/albertina-modern/" in path else "Albertina"

    return {
        "source": "albertina",
        "source_id": url,
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": 1010,
        "city": "Wien",
        "address": None,
        "price_min": None,
        "price_text": None,
        "category": None,
        "description": None,
        "status": "scheduled",
    }


def main():
    listing = ea.fetch(LISTING)

    recs = []
    for path in find_links(listing):
        url = BASE + path
        rec = parse_detail(url, path)
        if not rec:
            continue
        if rec["end"] and rec["end"] < datetime.date.today().isoformat():
            continue
        recs.append(rec)

    ea.emit(recs)


if __name__ == "__main__":
    main()
