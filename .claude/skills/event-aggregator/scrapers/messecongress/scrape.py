import re

import ea

BASE = "https://vieconcenter.at"
SOURCE = "messecongress"

LI_RE = re.compile(r'<li class="h-full rounded-\[16px\][^"]*">(.*?)</li>', re.S)
TITLE_RE = re.compile(r'<h3 class="font-bold">(.*?)</h3>', re.S)
FIELD_RE = re.compile(
    r'icons/(date|place|entrance|organisator|ubahn|extLink)\.svg[^>]*/>\s*'
    r'<span>\s*(.*?)\s*</span>', re.S)
EXTLINK_RE = re.compile(
    r'icons/extLink\.svg[^>]*/>\s*<a href="([^"]+)"', re.S)

TWO_DATE_RANGE = re.compile(r"(\d{2})\.(\d{2})\.-(\d{2})\.(\d{2})\.(\d{4})")
DAY_RANGE = re.compile(r"(\d{2})\.-(\d{2})\.(\d{2})\.(\d{4})")
SINGLE_DATE = re.compile(r"(\d{2})\.(\d{2})\.(\d{4})")


def parse_dates(s):
    m = TWO_DATE_RANGE.search(s)
    if m:
        d1, mo1, d2, mo2, y = m.groups()
        return f"{y}-{mo1}-{d1}", f"{y}-{mo2}-{d2}"
    m = DAY_RANGE.search(s)
    if m:
        d1, d2, mo, y = m.groups()
        return f"{y}-{mo}-{d1}", f"{y}-{mo}-{d2}"
    m = SINGLE_DATE.search(s)
    if m:
        d, mo, y = m.groups()
        return f"{y}-{mo}-{d}", None
    return None, None


def main():
    page = ea.fetch(f"{BASE}/events")
    pages = [page]
    p = 2
    while True:
        nxt = ea.fetch(f"{BASE}/events/p{p}")
        if nxt == pages[-1]:
            break
        pages.append(nxt)
        p += 1
        if p > 10:
            break

    seen = set()
    records = []
    for page_html in pages:
        for li_m in LI_RE.finditer(page_html):
            block = li_m.group(1)
            tm = TITLE_RE.search(block)
            if not tm:
                continue
            title = ea.text(tm.group(1))
            fields = {}
            for fm in FIELD_RE.finditer(block):
                key, val = fm.group(1), ea.text(fm.group(2))
                fields[key] = val
            elm = EXTLINK_RE.search(block)
            url = elm.group(1) if elm else None
            if not url:
                continue
            if url in seen:
                continue
            seen.add(url)

            start, end = parse_dates(fields.get("date") or "")
            if not start:
                continue

            venue = fields.get("place")
            extra = {}
            if fields.get("entrance"):
                extra["entrance"] = fields["entrance"]
            if fields.get("organisator"):
                extra["organizer"] = fields["organisator"]
            if fields.get("ubahn"):
                extra["ubahn"] = fields["ubahn"]

            records.append({
                "source": SOURCE,
                "source_id": url,
                "url": url,
                "title": title,
                "start": start,
                "end": end,
                "venue": venue,
                "district": 1020,
                "city": "Wien",
                "address": None,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": None,
                "extra": extra or None,
            })

    ea.emit(records)


if __name__ == "__main__":
    main()
