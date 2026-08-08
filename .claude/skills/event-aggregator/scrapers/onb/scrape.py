import datetime
import re
import sys

import ea


def safe_fetch(url, tries=3):
    last = None
    for _ in range(tries):
        try:
            return ea.fetch(url, timeout=30)
        except Exception as e:  # noqa: BLE001
            last = e
    print(f"warn: giving up on {url}: {last}", file=sys.stderr)
    return None

BASE = "https://www.onb.ac.at"

MUSEUMS = {
    "prunksaal": {
        "name": "Prunksaal",
        "venue": "Prunksaal der Österreichischen Nationalbibliothek",
    },
    "literaturmuseum": {
        "name": "Literaturmuseum",
        "venue": "Literaturmuseum der Österreichischen Nationalbibliothek",
    },
    "papyrusmuseum": {
        "name": "Papyrusmuseum",
        "venue": "Papyrusmuseum der Österreichischen Nationalbibliothek",
    },
    "globenmuseum": {
        "name": "Globenmuseum",
        "venue": "Globenmuseum der Österreichischen Nationalbibliothek",
    },
    "esperantomuseum": {
        "name": "Esperantomuseum",
        "venue": "Esperantomuseum der Österreichischen Nationalbibliothek",
    },
}

# All ONB museum locations are in the 1st district (Josefsplatz, Johannesgasse,
# Palais Mollard / Neue Burg).
DISTRICT = 1010

NAME_TO_VENUE = {v["name"]: v["venue"] for v in MUSEUMS.values()}

RANGE_DASH_RE = re.compile(
    r'(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]{3,10}\.?\s*\d{4})\s*[–‒-]\s*'
    r'(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]{3,10}\.?\s*\d{4})')
RANGE_BIS_RE = re.compile(
    r'(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]{3,10})\s*bis\s*'
    r'(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]{3,10}\.?\s*\d{4})')
H1_RE = re.compile(r'<h1>\s*([^<]+?)\s*</h1>')
DETAIL_META_RE = re.compile(r'<div class="detail-meta">(.*?)<section class="text', re.S)
DATE_STRONG_RE = re.compile(r'<strong>\s*(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]{3,10}\s*\d{4})\s*</strong>')
TIME_RE = re.compile(r'(\d{1,2})[.,:](\d{2})\s*Uhr')
CATEGORY_RE = re.compile(r'([^<>\n]+?)<br\s*/?>\s*</h2></div><div class="detail-meta">', re.S)
YEAR_RE = re.compile(r'\d{4}')

EXHIBIT_URL_RE = re.compile(r'href="(/museen/([a-z]+)/(?:programm|besuch)/[a-z0-9\-]+(?:/i)?)"')
EVENT_URL_RE = re.compile(r'href="(/museen/([a-z]+)/kalender/[^"?]+)"')


def title_of(html):
    m = H1_RE.search(html)
    return ea.text(m.group(1)) if m else None


def parse_range(html):
    m = RANGE_DASH_RE.search(html)
    if m:
        return ea.de_date(m.group(1)), ea.de_date(m.group(2))
    m = RANGE_BIS_RE.search(html)
    if m:
        year = YEAR_RE.search(m.group(2))
        year = year.group(0) if year else None
        return ea.de_date(m.group(1), default_year=year), ea.de_date(m.group(2))
    return None, None


def exhibition_links(mkey):
    html = safe_fetch(f"{BASE}/museen/{mkey}")
    if not html:
        return []
    out = []
    seen = set()
    for m in EXHIBIT_URL_RE.finditer(html):
        href, key = m.group(1), m.group(2)
        if key != mkey:
            continue
        if href in seen:
            continue
        if "vergangene" in href or "wanderausstellung" in href:
            continue
        if "/programm/" in href or href.endswith("/dauerausstellung"):
            seen.add(href)
            out.append(href)
    return out


def scrape_exhibition(mkey, href, today):
    url = BASE + href
    html = safe_fetch(url)
    if not html:
        return None
    title = title_of(html)
    if not title:
        return None
    permanent = href.endswith("/dauerausstellung")
    if permanent:
        title = f"{MUSEUMS[mkey]['name']} – Dauerausstellung"
    start, end = parse_range(html)

    if permanent:
        return {
            "source": "onb",
            "source_id": url,
            "url": url,
            "title": title,
            "start": start or today.isoformat(),
            "end": None,
            "venue": MUSEUMS[mkey]["venue"],
            "district": DISTRICT,
            "city": "Wien",
            "price_min": None,
            "price_text": None,
            "category": "Dauerausstellung",
            "extra": {"permanent": True},
        }

    if not start:
        return None
    if end and end < today.isoformat():
        return None
    return {
        "source": "onb",
        "source_id": url,
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": MUSEUMS[mkey]["venue"],
        "district": DISTRICT,
        "city": "Wien",
        "price_min": None,
        "price_text": None,
        "category": "Sonderausstellung",
    }


def event_links(mkey):
    html = safe_fetch(f"{BASE}/museen/{mkey}/kalender")
    if not html:
        return []
    out = []
    seen = set()
    for m in EVENT_URL_RE.finditer(html):
        href, key = m.group(1), m.group(2)
        if key != mkey or href in seen:
            continue
        seen.add(href)
        out.append(href)
    return out


def scrape_event(mkey, href, cutoff):
    url = BASE + href
    html = safe_fetch(url)
    if not html:
        return None
    title = title_of(html)
    if not title:
        return None
    meta_m = DETAIL_META_RE.search(html)
    if not meta_m:
        return None
    meta_block = meta_m.group(1)
    date_m = DATE_STRONG_RE.search(meta_block)
    if not date_m:
        # recurring / bookable activity with no published occurrence date
        return None
    start = ea.de_date(date_m.group(1))
    if not start:
        return None
    time_m = TIME_RE.search(meta_block)
    if time_m:
        start = f"{start}T{int(time_m.group(1)):02d}:{time_m.group(2)}"
    if start[:10] < datetime.date.today().isoformat():
        return None

    plain = ea.text(meta_block) or ""
    price_min, price_text = None, None
    if re.search(r"kostenfrei|eintritt frei|freier eintritt", plain, re.I):
        price_min, price_text = 0.0, plain
    else:
        price_min, price_text = ea.price(plain)

    cat_m = CATEGORY_RE.search(html)
    category = ea.text(cat_m.group(1)) if cat_m else None
    venue = NAME_TO_VENUE.get(category, MUSEUMS[mkey]["venue"])

    return {
        "source": "onb",
        "source_id": url,
        "url": url,
        "title": title,
        "start": start,
        "end": None,
        "venue": venue,
        "district": DISTRICT,
        "city": "Wien",
        "price_min": price_min,
        "price_text": price_text,
        "category": category or MUSEUMS[mkey]["name"],
    }


def main():
    today = datetime.date.today()
    cutoff = ea.horizon()
    recs = []

    for mkey in MUSEUMS:
        for href in exhibition_links(mkey):
            rec = scrape_exhibition(mkey, href, today)
            if rec:
                recs.append(rec)

    seen_occurrences = set()
    for mkey in MUSEUMS:
        for href in event_links(mkey):
            rec = scrape_event(mkey, href, cutoff)
            if not rec:
                continue
            # Museum-wide events (e.g. "Lange Nacht der Museen") are cross-listed
            # verbatim under every participating museum's calendar; keep one.
            dedup_key = (rec["title"], rec["start"])
            if dedup_key in seen_occurrences:
                continue
            seen_occurrences.add(dedup_key)
            recs.append(rec)

    ea.emit(recs)


if __name__ == "__main__":
    main()
