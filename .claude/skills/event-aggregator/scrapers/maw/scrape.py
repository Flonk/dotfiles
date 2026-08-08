import re
import sys

import ea

URL = "https://www.maw.co.at/de/kongresskalender"

PANEL_RE = re.compile(
    r'<div class="panel panel-default"(.*?)(?=<div class="panel panel-default"|$)',
    re.S)
SUBLINE_RE = re.compile(r'<span class="subline">(.*?)</span>', re.S)
TITLE_RE = re.compile(r'<span class="subline">.*?</span>\s*<br\s*/?>\s*(.*?)\s*</a>', re.S)
ICS_RE = re.compile(r'kongress/ics/([A-Za-z0-9_]+?)(?:_D|_EN)?\.ics')
LOGO_RE = re.compile(r'kongress/logos/([A-Za-z0-9_]+)\.\w+')
ROW_RE = re.compile(
    r'<div class="calendar-left">\s*([^<]*?)\s*</div>\s*'
    r'<div class="calendar-right">\s*(.*?)\s*</div>', re.S)

EN_MONTHS = ("January February March April May June July August September "
             "October November December").split()
EN_RANGE_SAME = re.compile(
    r'^(' + "|".join(EN_MONTHS) + r') (\d{1,2}) - (\d{1,2}), (\d{4})$')
EN_RANGE_CROSS = re.compile(
    r'^(' + "|".join(EN_MONTHS) + r') (\d{1,2}) - (' + "|".join(EN_MONTHS) +
    r') (\d{1,2}), (\d{4})$')
DE_RANGE = re.compile(
    r'^(\d{1,2})\.\s*-\s*(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s*(\d{4})$')
DE_SINGLE = re.compile(r'^(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s*(\d{4})$')


def parse_dates(date_part):
    date_part = date_part.strip()
    m = EN_RANGE_CROSS.match(date_part)
    if m:
        mo1, d1, mo2, d2, y = m.groups()
        start = f"{y}-{ea.MON[mo1]:02d}-{int(d1):02d}"
        end = f"{y}-{ea.MON[mo2]:02d}-{int(d2):02d}"
        return start, end
    m = EN_RANGE_SAME.match(date_part)
    if m:
        mo, d1, d2, y = m.groups()
        start = f"{y}-{ea.MON[mo]:02d}-{int(d1):02d}"
        end = f"{y}-{ea.MON[mo]:02d}-{int(d2):02d}"
        return start, end
    m = DE_RANGE.match(date_part)
    if m:
        d1, d2, mo, y = m.groups()
        mn = ea.MON.get(mo.capitalize())
        if not mn:
            return None, None
        start = f"{y}-{mn:02d}-{int(d1):02d}"
        end = f"{y}-{mn:02d}-{int(d2):02d}"
        return start, end
    m = DE_SINGLE.match(date_part)
    if m:
        d1, mo, y = m.groups()
        mn = ea.MON.get(mo.capitalize())
        if not mn:
            return None, None
        start = f"{y}-{mn:02d}-{int(d1):02d}"
        return start, start
    return None, None


def parse_venue(rows):
    v = rows.get("Veranstaltungsort")
    if not v:
        return None, None, None, None
    v = ea.text(v)
    if not v:
        return None, None, None, None
    parts = [p.strip() for p in v.split(",")]
    venue = parts[0] if parts else None
    m = re.search(r'(\d{4,5})\s+([^,]+)', v)
    city = m.group(2).strip() if m else None
    addr_m = re.match(r'^(.*?)(\d{4,5}\s+[^,]+)', v, re.S)
    address = addr_m.group(1).strip().rstrip(",").strip() if addr_m else None
    address = address or None
    district = ea.district(v)
    return venue, address, city, district


def build(panel_html, page_url):
    sm = SUBLINE_RE.search(panel_html)
    if not sm:
        return None
    subline = ea.text(sm.group(1)) or ""
    if "|" in subline:
        date_part, loc_part = [x.strip() for x in subline.split("|", 1)]
    else:
        date_part, loc_part = subline, ""
    start, end = parse_dates(date_part)
    if not start:
        sys.stderr.write(f"unparsed date: {subline!r}\n")
        return None

    tm = TITLE_RE.search(panel_html)
    title = ea.text(tm.group(1)) if tm else None
    if not title:
        return None

    ics_m = ICS_RE.search(panel_html)
    logo_m = LOGO_RE.search(panel_html)
    source_id = (ics_m.group(1) if ics_m else None) or \
        (logo_m.group(1) if logo_m else None) or title

    rows = {}
    for k, v in ROW_RE.findall(panel_html):
        k = ea.text(k)
        if k and k not in rows:
            rows[k] = v

    venue, address, city, district = parse_venue(rows)
    if not city and "," in loc_part:
        city = loc_part.split(",")[0].strip() or None

    url = page_url
    website = rows.get("Website")
    if website:
        wm = re.search(r'href="([^"]+)"', website)
        if wm:
            url = wm.group(1)
    if url == page_url:
        reg = rows.get("Teilnehmeranmeldung online")
        if reg:
            rm = re.search(r'href="([^"]+)"', reg)
            if rm:
                url = rm.group(1)

    return {
        "source": "maw",
        "source_id": source_id,
        "url": url,
        "title": title,
        "start": start,
        "end": end if end and end != start else None,
        "venue": venue,
        "district": district,
        "city": city,
        "address": address,
        "price_min": None,
        "price_text": None,
        "category": None,
        "description": None,
        "status": "scheduled",
    }


def main():
    page = ea.fetch(URL)
    records = []
    for pm in PANEL_RE.finditer(page):
        rec = build(pm.group(1), URL)
        if rec:
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
