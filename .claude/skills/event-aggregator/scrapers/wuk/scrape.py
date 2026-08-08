import datetime
import html
import re
import sys

import ea

BASE = "https://www.wuk.at"
LIST_URL = BASE + "/programm/"
ITEM_SEP = '<div class="event-list-item d-flex">'
MORE_RE = re.compile(r'href="(/programm/\?filter[^"]*)"[^>]*data-extbase-replace')
HREF_RE = re.compile(r'href="([^"]+)"')
TITLE_RE = re.compile(r'<h2 class="h3 text-uppercase[^"]*">\s*<a[^>]*>([^<]*)</a>')
SUBTITLE_RE = re.compile(r'<h3 class="h5 font-weight-normal text-uppercase mb-half">([^<]*)</h3>')
THEME_RE = re.compile(r'<span class="theme-list-item[^"]*">([^<]*)</span>')
DESC_RE = re.compile(r'<p class="event-list-item-text mb-half">(.*?)</p>', re.S)
META_RE = re.compile(r'<p class="event-list-item-meta-info">(.*?)</p>', re.S)

MAX_PAGES = 15


def fetch_items():
    url = LIST_URL
    chunks = []
    for _ in range(MAX_PAGES):
        page = ea.fetch(url)
        chunks.extend(page.split(ITEM_SEP)[1:])
        m = MORE_RE.search(page)
        if not m:
            break
        url = BASE + html.unescape(m.group(1))
    return chunks


def clean_meta(inner):
    parts = re.split(r"<br[^>]*>", inner, maxsplit=1)
    date_html = parts[0]
    venue_html = parts[1] if len(parts) > 1 else ""
    date_text = ea.text(date_html) or ""
    venue_text = ea.text(venue_html) or ""
    venue_text = re.sub(r"^[,\s]+", "", venue_text)
    return date_text, venue_text


def last_date(s, guess_year):
    d = ea.de_date(s)
    if d:
        return d
    for sep in (" und ", "&"):
        if sep in s:
            d = ea.de_date(s.rsplit(sep, 1)[-1])
            if d:
                return d
    return ea.de_date(s, default_year=guess_year)


def parse_period(raw, guess_year):
    raw = html.unescape(raw).strip()
    if not raw:
        return None, None
    if " bis " in raw:
        left, right = raw.split(" bis ", 1)
        end = ea.de_date(right)
        ym = re.search(r"(\d{4})", right)
        y = ym.group(1) if ym else guess_year
        start = ea.de_date(left, default_year=y)
        return start, end
    if " - " in raw:
        left, right = raw.split(" - ", 1)
        if re.match(r"^\s*[A-Za-zÄÖÜäöü]{2,4}\.?\s+\d", right):
            end = ea.de_date(right)
            ym = re.search(r"(\d{4})", right)
            y = ym.group(1) if ym else guess_year
            start = ea.de_date(left, default_year=y)
            return start, end
    end = last_date(raw, guess_year)
    if not end:
        return None, None
    m = re.match(r"^\D*?(\d{1,2})\.", raw)
    if m:
        first_day = int(m.group(1))
        end_day = int(end[8:10])
        if first_day < end_day:
            y, mo = end[0:4], end[5:7]
            rest = end[10:]
            start = f"{y}-{mo}-{first_day:02d}{rest}"
            return start, end
    return end, None


PRICE_RE = re.compile(
    r'Preis</strong><br><div><p>(.*?)</p>', re.S)


def fetch_price(url):
    try:
        page = ea.fetch(url)
    except Exception as e:
        print(f"detail fetch failed {url}: {e}", file=sys.stderr)
        return None, None
    m = PRICE_RE.search(page)
    if not m:
        return None, None
    raw = ea.text(m.group(1))
    if raw and re.search(r"kostenfrei", raw, re.I):
        return 0.0, raw
    return ea.price(m.group(1))


def main():
    guess_year = datetime.date.today().year
    cutoff = ea.horizon()
    chunks = fetch_items()

    records = []
    for chunk in chunks:
        hm = HREF_RE.search(chunk)
        if not hm:
            continue
        href = hm.group(1)
        url = BASE + href if href.startswith("/") else href
        slug = href.strip("/").split("/")[-1]

        tm = TITLE_RE.search(chunk)
        title = ea.text(tm.group(1)) if tm else None
        if not title:
            continue
        sm = SUBTITLE_RE.search(chunk)
        subtitle = ea.text(sm.group(1)) if sm else None
        if subtitle:
            title = f"{title} - {subtitle}"

        categories = [ea.text(t) for t in THEME_RE.findall(chunk)]
        categories = [c for c in categories if c]
        category = ", ".join(categories) if categories else None

        dm = DESC_RE.search(chunk)
        description = ea.text(dm.group(1)) if dm else None

        mm = META_RE.search(chunk)
        if not mm:
            continue
        date_text, venue_text = clean_meta(mm.group(1))
        start, end = parse_period(date_text, guess_year)
        if not start:
            print(f"skip (no date): {url} {date_text!r}", file=sys.stderr)
            continue

        district = ea.district(venue_text) or 1090
        venue = venue_text or "WUK"

        price_min, price_text = fetch_price(url)

        start_d = datetime.date.fromisoformat(start[:10])
        if start_d > cutoff:
            continue

        records.append({
            "source": "wuk",
            "source_id": slug,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": district,
            "city": "Wien",
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
            "description": description,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
