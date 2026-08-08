import datetime
import re
import sys

import ea

BASE = "https://www.khm.at"
MAIN_URL = f"{BASE}/besuchen/ausstellungen/"
VORSCHAU_URL = f"{BASE}/ausstellungen/vorschau"

MAIN_ADDRESS = ("Kunsthistorisches Museum", "Maria-Theresien-Platz", 1010)
NH_ADDRESS = ("Neue Hofburg", "Heldenplatz", 1010)

SECTION_VENUE = {
    "Dauerausstellungen": MAIN_ADDRESS,
    "Dauerausstellungen Neue Hofburg": NH_ADDRESS,
}

CARD_LINK_RE = re.compile(
    r'<div class="card-link">\s*<a href="([^"]+)"[^>]*>\s*'
    r'<span class="visually-hidden">(.*?)</span>')
PROGRESS_RE = re.compile(
    r'class="(?:progress-label|no-progress-label)">'
    r'(?:<span[^>]*>[^<]*</span>)?\s*(.*?)\s*</(?:div|p)>', re.S)
BADGE_RE = re.compile(r'class="badge me-1(?: badge-small)?">([^<]*)</div>')
DATE_RANGE_RE = re.compile(
    r'(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*(?:\d{4})?)\s*-\s*'
    r'(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*(\d{4}))')
BIS_RE = re.compile(r'\bbis\s+(.+)')
SEIT_RE = re.compile(r'\bseit\s+(.+)')

INFOBOX_RE = re.compile(
    r'<p class="has-icon"><span[^>]*>date_range</span>(.*?)</p>\s*'
    r'<p class="has-icon"><span[^>]*>location_on</span>\s*(.*?)</p>\s*'
    r'<p class="has-icon"><span[^>]*>confirmation_number</span>\s*(.*?)</p>',
    re.S)


def cards_from_fragment(frag):
    cards = []
    links = list(CARD_LINK_RE.finditer(frag))
    for i, m in enumerate(links):
        href, title_html = m.groups()
        start_pos = m.end()
        end_pos = links[i + 1].start() if i + 1 < len(links) else len(frag)
        chunk = frag[start_pos:end_pos]
        pm = PROGRESS_RE.search(chunk)
        progress = ea.text(pm.group(1)) if pm else None
        bm = BADGE_RE.search(chunk)
        badge = ea.text(bm.group(1)) if bm else None
        cards.append({
            "href": href,
            "title": ea.text(title_html),
            "progress": progress,
            "badge": badge,
        })
    return cards


def parse_date_range(text):
    if not text:
        return None, None
    m = DATE_RANGE_RE.search(text)
    if m:
        start_part, end_part, year = m.groups()
        return ea.de_date(start_part, default_year=year), ea.de_date(end_part)
    m = SEIT_RE.search(text)
    if m:
        return ea.de_date(m.group(1)), None
    m = BIS_RE.search(text)
    if m:
        return None, ea.de_date(m.group(1))
    return None, None


def detail_info(slug, cache):
    if slug in cache:
        return cache[slug]
    url = f"{BASE}/ausstellungen/{slug}"
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"skip detail {slug}: {e}\n")
        cache[slug] = None
        return None
    m = INFOBOX_RE.search(page)
    info = None
    if m:
        date_text, loc_text, price_text = (ea.text(g) for g in m.groups())
        s, e = parse_date_range(date_text)
        info = {
            "start": s,
            "end": e,
            "location": loc_text,
            "price_text": price_text,
        }
    cache[slug] = info
    return info


def slug_of(href):
    return href.rstrip("/").rsplit("/", 1)[-1]


def section_records(title, frag, detail_cache):
    out = []
    today = datetime.date.today().isoformat()
    for card in cards_from_fragment(frag):
        href = card["href"]
        if not href.startswith("/ausstellungen/"):
            continue
        slug = slug_of(href)
        url = BASE + href
        card_title = card["title"]
        if not card_title:
            continue

        start, end = parse_date_range(card["progress"])
        venue, address, district = SECTION_VENUE.get(title, MAIN_ADDRESS)
        price_min, price_text = None, None
        permanent = False

        if title not in SECTION_VENUE and start is None:
            info = detail_info(slug, detail_cache)
            if info:
                if info["start"]:
                    start = info["start"]
                if info["end"]:
                    end = info["end"]
                if info["location"]:
                    address = info["location"]
                if info["price_text"]:
                    price_min, price_text = ea.price(info["price_text"])

        if start is None:
            start = today
            permanent = permanent or end is None
        if end is None:
            permanent = True

        rec = {
            "source": "khm",
            "source_id": slug,
            "url": url,
            "title": card_title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": district,
            "city": "Wien",
            "address": address,
            "price_min": price_min,
            "price_text": price_text,
            "category": card["badge"] or title,
            "description": None,
            "status": "scheduled",
        }
        if permanent:
            rec["extra"] = {"permanent": True}
        out.append(rec)
    return out


def section_title_hxget_pairs(page, hx_prefix):
    titles = [(m.start(), m.group(1))
              for m in re.finditer(r'data-title="([^"]*)"', page)]
    hxgets = [(m.start(), m.group(1))
              for m in re.finditer(
                  r'hx-get="(' + re.escape(hx_prefix) + r'[^"]*)"', page)]
    pairs = []
    for pos, url in hxgets:
        title = None
        for tpos, t in titles:
            if tpos < pos:
                title = t
            else:
                break
        title = (title or "Ausstellungen").replace("\xa0", " ")
        pairs.append((title, url.replace("&amp;", "&")))
    return pairs


def main():
    detail_cache = {}
    by_slug = {}

    page = ea.fetch(MAIN_URL)
    for title, frag_url in section_title_hxget_pairs(
            page, "/ausstellungen/x.htm"):
        full = frag_url if frag_url.startswith("http") else BASE + frag_url
        try:
            frag = ea.fetch(full)
        except Exception as e:
            sys.stderr.write(f"skip section {title}: {e}\n")
            continue
        for rec in section_records(title, frag, detail_cache):
            by_slug[rec["source_id"]] = rec

    vpage = ea.fetch(VORSCHAU_URL)
    for title, frag_url in section_title_hxget_pairs(
            vpage, "/ausstellungen/vorschau/x.htm"):
        full = frag_url if frag_url.startswith("http") else BASE + frag_url
        try:
            frag = ea.fetch(full)
        except Exception as e:
            sys.stderr.write(f"skip vorschau section: {e}\n")
            continue
        for rec in section_records("Vorschau", frag, detail_cache):
            by_slug.setdefault(rec["source_id"], rec)

    ea.emit(list(by_slug.values()))


if __name__ == "__main__":
    main()
