import datetime
import re
import sys

import ea

BASE = "https://www.wienmuseum.at/ausstellungen"

VENUE_INFO = {
    "wien museum": ("Wien Museum", 1040, "1040 Wien, Karlsplatz 8"),
    "musa": ("musa", 1010, "1010 Wien, Felderstraße 6-8"),
}

MONTHS = ea.MON


def split_daterange_and_venue(raw):
    raw = re.sub(r"<br[^>]*>", "|", raw)
    parts = [p.strip() for p in raw.split("|") if p.strip()]
    if not parts:
        return None, None
    dr = ea.text(parts[0])
    venue = ea.text(parts[1]) if len(parts) > 1 else None
    return dr, venue


def parse_daterange(dr):
    if not dr:
        return None, None
    m = re.match(
        r"(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\.?\s*(\d{4})?\s*[–\-]\s*"
        r"(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\.?\s*(\d{4})",
        dr)
    if not m:
        return None, None
    d1, mo1n, y1, d2, mo2n, y2 = m.groups()
    y1 = y1 or y2
    mo1 = MONTHS.get(mo1n.capitalize()) or MONTHS.get(mo1n[:3].capitalize())
    mo2 = MONTHS.get(mo2n.capitalize()) or MONTHS.get(mo2n[:3].capitalize())
    if not (mo1 and mo2):
        return None, None
    start = f"{int(y1):04d}-{mo1:02d}-{int(d1):02d}"
    end = f"{int(y2):04d}-{mo2:02d}-{int(d2):02d}"
    return start, end


def fetch_price(url):
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"detail fetch failed {url}: {e}\n")
        return None, None
    m = re.search(
        r"Eintrittspreise</h\d>.*?module_text[^\"]*\"[^>]*>(.*?)</div>",
        page, re.S)
    if not m:
        return None, None
    return ea.price(m.group(1))


def venue_lookup(name):
    if not name:
        return None, None, None
    return VENUE_INFO.get(name.strip().lower(), (name, None, None))


def section(page, pid):
    m = re.search(r"<section id=['\"]%s['\"].*?</section>" % pid, page, re.S)
    return m.group(0) if m else None


def parse_current(page):
    recs = []
    s = section(page, "26817")
    if not s:
        return recs
    for chunk in s.split("<li class='newsSliderElem")[1:]:
        t = re.search(r"class='h1'>(.*?)</h2>", chunk, re.S)
        sub = re.search(r"class='h2-reg'>(.*?)</p>", chunk, re.S)
        dr = re.search(r"class='h3-reg'>(.*?)</p>", chunk, re.S)
        url = re.search(r"href='(https://www\.wienmuseum\.at/[^']*)'", chunk)
        if not (t and url):
            continue
        title = ea.text(t.group(1))
        url_v = url.group(1).strip()
        subtitle = ea.text(sub.group(1)) if sub else None
        if dr:
            draw, venue_name = split_daterange_and_venue(dr.group(1))
            start, end = parse_daterange(draw)
            permanent = False
        else:
            start, end, venue_name, permanent = None, None, None, True
        recs.append((title, subtitle, url_v, start, end, venue_name, permanent))
    return recs


def parse_upcoming(page):
    recs = []
    s = section(page, "26819")
    if not s:
        return recs
    for chunk in s.split("<li class='twoOneBlock")[1:]:
        t = re.search(r"twoOneTitle truncate2' tabindex='-1'>(.*?)</h2>", chunk, re.S)
        sub = re.search(r"twoOneText mob-reg26 truncate3'>(.*?)</div>", chunk, re.S)
        dr = re.search(r"bold20 mob-bold26' role='text'>(.*?)</div>", chunk, re.S)
        url = re.search(r"href='(https://www\.wienmuseum\.at/[^']*)'", chunk)
        if not (t and url):
            continue
        title = ea.text(t.group(1))
        url_v = url.group(1).strip()
        subtitle = ea.text(sub.group(1)) if sub else None
        start = end = venue_name = None
        permanent = False
        if dr:
            draw, venue_name = split_daterange_and_venue(dr.group(1))
            start, end = parse_daterange(draw)
        recs.append((title, subtitle, url_v, start, end, venue_name, permanent))
    return recs


def main():
    page = ea.fetch(BASE)
    all_recs = parse_current(page) + parse_upcoming(page)

    out = []
    for title, subtitle, url, start, end, venue_name, permanent in all_recs:
        if not start and not permanent:
            sys.stderr.write(f"skip (no parseable start): {title}\n")
            continue
        venue, district, address = venue_lookup(venue_name)
        price_min, price_text = fetch_price(url)
        rec = {
            "source": "wienmuseum",
            "source_id": url.rstrip("/").rsplit("/", 1)[-1],
            "url": url,
            "title": title,
            "start": start if start else datetime.date.today().isoformat(),
            "end": None if permanent else end,
            "venue": venue,
            "district": district,
            "city": "Wien",
            "address": address,
            "price_min": price_min,
            "price_text": price_text,
            "category": "Ausstellung",
            "description": subtitle,
            "extra": {"permanent": True} if permanent else {},
        }
        out.append(rec)

    ea.emit(out)


if __name__ == "__main__":
    main()
