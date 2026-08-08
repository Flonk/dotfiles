import datetime
import json
import re
import sys
import urllib.parse
import urllib.request

import ea

AJAX_URL = "https://szene.wien/?wpgb-ajax=refresh"
VENUE_FALLBACK = "((szene)) Wien"
ADDRESS_FALLBACK = "Hauffgasse 26, 1110 Wien"
DISTRICT_FALLBACK = 1110

WPGB_SETTINGS = json.dumps({
    "is_main_query": False,
    "main_query": [],
    "permalink": "https://szene.wien/",
    "facets": [1, 2],
    "lang": "",
    "id": 1,
})

CARD_RE = re.compile(
    r'<article class="wpgb-card[^"]*wpgb-post-(\d+)"[^>]*>.*?'
    r'<h3 class="wpgb-block-1">(.*?)</h3>'
    r'(?:<div class="wpgb-block-3">(.*?)</div>)?'
    r'<div class="wpgb-block-2">\(\((.*?)\)\)</div>.*?'
    r'<a class="wpgb-card-layer-link" href="([^"]+)">',
    re.S,
)

TIME_RE = re.compile(r'class = "time">\s*<span>\s*\(\((.*?)\)\)', re.S)
LOCATION_RE = re.compile(r'<div class="location">\s*<b>([^<]*)</b><br>([^<]*)</div>')
EINLASS_RE = re.compile(r'class = "einlass"><b>Einlass </b>([\d:]+)')
BEGINN_RE = re.compile(r'class = "beginn"><b>Beginn </b>([\d:]+)')
TICKETS_RE = re.compile(r'class="tickets">')
TEXT_RE = re.compile(r'class = "text">(.*?)<div class="elementor-element', re.S)


def fetch_batch(offset):
    data = urllib.parse.urlencode({"wpgb": WPGB_SETTINGS}).encode()
    url = f"{AJAX_URL}&_mehr_laden={offset}"
    req = urllib.request.Request(url, data=data, headers={
        "User-Agent": ea.UA,
        "X-Requested-With": "XMLHttpRequest",
        "Accept-Language": "de-AT,de;q=0.9,en;q=0.8",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        body = r.read().decode("utf-8", "replace")
    return json.loads(body)


def list_cards():
    cards = []
    offset = 0
    while True:
        d = fetch_batch(offset)
        posts = d.get("posts") or ""
        found = list(CARD_RE.finditer(posts))
        if not found:
            break
        cards.extend(found)
        offset += 12
        if offset > (d.get("total") or 0):
            break
        if offset > 500:
            break
    return cards


def build(m, cutoff):
    post_id, title_raw, free_raw, date_raw, url = m.groups()
    title = ea.text(title_raw)
    if not title:
        return None
    d = ea.de_date(ea.text(date_raw))
    if not d:
        return None
    start_date = datetime.date.fromisoformat(d[:10])
    if start_date > cutoff:
        return None

    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"detail fetch failed {url}: {e}\n")
        page = ""

    beginn_m = BEGINN_RE.search(page)
    start = f"{d}T{beginn_m.group(1)}" if beginn_m else d

    loc_m = LOCATION_RE.search(page)
    venue = ea.text(loc_m.group(1)) if loc_m else VENUE_FALLBACK
    address = ea.text(loc_m.group(2)) if loc_m else ADDRESS_FALLBACK
    district = ea.district(address) or DISTRICT_FALLBACK

    is_free = bool(free_raw and re.search(r"frei|gratis", free_raw, re.I))
    has_tickets = bool(TICKETS_RE.search(page))
    if is_free:
        price_min, price_text = 0.0, ea.text(free_raw)
    elif has_tickets:
        price_min, price_text = None, None
    else:
        price_min, price_text = None, None

    text_m = TEXT_RE.search(page)
    description = ea.text(text_m.group(1)) if text_m else None

    return {
        "source": "szene",
        "source_id": post_id,
        "url": url,
        "title": title,
        "start": start,
        "end": None,
        "venue": venue,
        "district": district,
        "city": "Wien",
        "address": address,
        "price_min": price_min,
        "price_text": price_text,
        "category": None,
        "description": description,
        "status": "scheduled",
    }


def main():
    cutoff = ea.horizon()
    cards = list_cards()
    seen = set()
    records = []
    for m in cards:
        url = m.group(5)
        if url in seen:
            continue
        seen.add(url)
        rec = build(m, cutoff)
        if rec:
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
