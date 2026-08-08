import concurrent.futures
import datetime
import json
import re
import sys
import time
import urllib.request

import ea

API_URL = "https://www.wko.at/api/event/filter"
SOURCE = "wko"

DETAIL_WORKERS = 8
DETAIL_RETRIES = 4

DATE_RE = re.compile(
    r'<svg class="icon icon-date">.*?</svg>\s*(.*?)\s*</div>', re.S)
TITLE_RE = re.compile(r'class="card-title h4">\s*<a href="[^"]+">(.*?)</a>', re.S)
LOC_RE = re.compile(
    r'<svg class="icon icon-(pin|video)">.*?</svg>\s*(.*?)\s*</div>', re.S)

# Free-text location strings that carry no place at all (virtual-meeting
# placeholders, dashes used as "n/a"). Never treated as a city.
NONPLACE_EXACT = {"-", "- -", "online", "webinar", "ms teams", "teams", "zoom",
                   "n/a", "tba"}
# Austrian federal states sometimes appear alone (no town) - a state is not
# a city, so these must not leak into the city field.
BUNDESLAENDER = {"burgenland", "kärnten", "niederösterreich",
                  "oberösterreich", "salzburg", "steiermark", "tirol",
                  "vorarlberg", "wien"}
BARE_DIGITS_RE = re.compile(r"^[\d\-\s]+$")
# "<postal-code-ish prefix> <City Name>" - the prefix may be an Austrian
# 4-digit PLZ or a foreign postal code in any punctuation (e.g. "546 36",
# "01-222", "135-0063"); only a plain 4-digit prefix is checked against
# ea.district (foreign PLZs are never Austrian districts).
LOC_PREFIX_RE = re.compile(r"^[\d][\d\-\s]{0,11}\s+([A-ZÄÖÜ].+)$")


def parse_pin_text(val):
    """Parse an icon-pin location string into (city, district).

    Handles 'PLZ City' (Austrian or foreign), plain city names, and filters
    out placeholders ('- -', 'MS Teams', ...) and bare federal-state names.
    Never invents a city: returns (None, None) when the text carries no
    identifiable place.
    """
    v = re.sub(r"\s+", " ", val or "").strip(" .")
    if not v:
        return None, None
    low = v.lower()
    if low in NONPLACE_EXACT or BARE_DIGITS_RE.match(v):
        return None, None
    m = LOC_PREFIX_RE.match(v)
    if m:
        prefix = v[:m.start(1)].strip()
        city = m.group(1).strip()
        district = ea.district(prefix) if re.fullmatch(r"\d{4}", prefix) else None
        return (city or None), district
    if low in BUNDESLAENDER:
        return None, None
    return v, None

MON = {
    "Jan": 1, "Feb": 2, "Mär": 3, "Apr": 4, "Mai": 5, "Jun": 6,
    "Jul": 7, "Aug": 8, "Sep": 9, "Okt": 10, "Nov": 11, "Dez": 12,
}

SINGLE_DT_RE = re.compile(
    r"(\d{2})\. (\w{3})\. (\d{4}), (\d{2}):(\d{2}) Uhr")
RANGE_RE = re.compile(
    r"(\d{2})\. (\w{3})\. (\d{4}) . (\d{2})\. (\w{3})\. (\d{4})")
SINGLE_D_RE = re.compile(r"(\d{2})\. (\w{3})\. (\d{4})$")


def parse_dates(txt):
    m = SINGLE_DT_RE.search(txt)
    if m:
        d, mon, y, h, mi = m.groups()
        start = f"{y}-{MON[mon]:02d}-{int(d):02d}T{h}:{mi}"
        return start, None
    m = RANGE_RE.search(txt)
    if m:
        d1, mon1, y1, d2, mon2, y2 = m.groups()
        start = f"{y1}-{MON[mon1]:02d}-{int(d1):02d}"
        end = f"{y2}-{MON[mon2]:02d}-{int(d2):02d}"
        return start, end
    m = SINGLE_D_RE.search(txt)
    if m:
        d, mon, y = m.groups()
        start = f"{y}-{MON[mon]:02d}-{int(d):02d}"
        return start, None
    return None, None


def fetch_batch(offset, count=200):
    body = json.dumps({
        "count": count, "offsetCurrent": offset, "aktuelle": True,
        "place": "Österreich", "withStorniert": False,
        "withAusgebucht": False, "withAbgeschlossen": False,
        "von": "", "bis": "", "veranstaltungstyp": "", "zielgruppe": "",
        "kategorie": "",
    }).encode()
    req = urllib.request.Request(API_URL, data=body, headers={
        "User-Agent": ea.UA,
        "Accept-Language": "de-AT,de;q=0.9,en;q=0.8",
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def main():
    cutoff = ea.horizon()
    records = []
    seen = set()
    offset = 0
    total = None
    while True:
        try:
            data = fetch_batch(offset)
        except Exception as e:
            sys.stderr.write(f"fetch failed at offset {offset}: {e}\n")
            break
        elements = data.get("elements") or []
        total = data.get("totalCount")
        if total is not None:
            total = int(total)
        if not elements:
            break
        batch_max = None
        for el in elements:
            im = re.search(r'data-gtm-item-id="([^"]+)"', el)
            um = re.search(r'data-gtm-item-url="([^"]+)"', el)
            if not im or not um:
                continue
            event_id, url = im.group(1), um.group(1)
            if event_id in seen:
                continue
            seen.add(event_id)

            tm = TITLE_RE.search(el)
            title = ea.text(tm.group(1)) if tm else None
            if not title:
                continue

            dm = DATE_RE.search(el)
            date_txt = ea.text(dm.group(1)) if dm else ""
            start, end = parse_dates(date_txt or "")
            if not start:
                continue

            try:
                start_date = datetime.date.fromisoformat(start[:10])
            except ValueError:
                start_date = None
            if start_date and (batch_max is None or start_date > batch_max):
                batch_max = start_date

            venue = None
            district = None
            city = None
            is_online = False
            has_loc = False
            lm = LOC_RE.search(el)
            if lm:
                has_loc = True
                kind, val = lm.group(1), ea.text(lm.group(2))
                if kind == "video":
                    is_online = True
                    venue = val
                elif val:
                    venue = val
                    city, district = parse_pin_text(val)

            extra = {"online": True} if is_online else None

            records.append({
                "source": SOURCE,
                "source_id": event_id,
                "url": url,
                "title": title,
                "start": start,
                "end": end,
                "venue": venue,
                "district": district,
                "city": city,
                "address": None,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": None,
                "extra": extra,
                "_needs_detail": (not has_loc) or (district is not None),
            })

        offset += len(elements)
        if total is not None and offset >= total:
            break
        if batch_max and batch_max > cutoff + datetime.timedelta(days=30):
            break
        if offset > 4000:
            break

    enrich(records)
    ea.emit(records)


def fetch_detail(url):
    """Fetch one detail page and pull its ld+json Place/address, if any.

    The list card is missing location entirely for ~20% of records
    (mostly foreign trade-fair listings that only name a venue in prose)
    and, for the ~11% resolved to a Vienna district, never carries a
    street address. Both live only in the detail page's ld+json. Returns
    an empty dict (record kept as-is) on repeated fetch failure - it never
    guesses a location from a failed fetch.
    """
    page = None
    for attempt in range(DETAIL_RETRIES):
        try:
            page = ea.fetch(url)
            break
        except Exception:
            if attempt + 1 < DETAIL_RETRIES:
                time.sleep(1.0 * (attempt + 1))
    if page is None:
        return {}

    nodes = ea.jsonld(page)
    place = next((n for n in nodes if n.get("@type") == "Place"), None)
    addr = next((n for n in nodes
                 if "streetAddress" in n or "postalCode" in n
                 or "addressLocality" in n), None)

    out = {}
    venue_name = ea.text(place.get("name")) if place and place.get("name") else None
    if venue_name:
        if re.match(r"(?i)^online\b", venue_name):
            out["online"] = True
        else:
            out["venue"] = venue_name

    if addr:
        street = ea.text(addr.get("streetAddress") or "")
        postal = addr.get("postalCode")
        locality = ea.text(addr.get("addressLocality") or "")
        if locality:
            out["city"] = locality
        if postal:
            d = ea.district(str(postal))
            if d:
                out["district"] = d
        if street and postal and locality:
            out["address"] = f"{street}, {postal} {locality}"
        elif street and locality:
            out["address"] = f"{street}, {locality}"

    return out


def enrich(records):
    """Fill in venue/city/district/address from detail pages.

    Only fetched for records the listing card left ambiguous: no location
    tag at all, or a Vienna district (where the listing text never carries
    a street). The other ~70% already have a usable city/district straight
    from the listing and are left untouched to keep request volume sane.
    """
    targets = [r for r in records if r.pop("_needs_detail", False)]
    if not targets:
        return
    with concurrent.futures.ThreadPoolExecutor(max_workers=DETAIL_WORKERS) as ex:
        futs = {ex.submit(fetch_detail, r["url"]): r for r in targets}
        for fut in concurrent.futures.as_completed(futs):
            r = futs[fut]
            try:
                extra = fut.result()
            except Exception as e:
                sys.stderr.write(f"detail failed {r['url']}: {e}\n")
                continue
            if extra.get("venue"):
                r["venue"] = extra["venue"]
            if extra.get("city") and not r.get("city"):
                r["city"] = extra["city"]
            if extra.get("district") and not r.get("district"):
                r["district"] = extra["district"]
            if extra.get("address"):
                r["address"] = extra["address"]
            if extra.get("online"):
                r["extra"] = {**(r.get("extra") or {}), "online": True}


if __name__ == "__main__":
    main()
