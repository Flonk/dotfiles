import datetime
import html
import re

import ea

BASE = "https://www.filmmuseum.at"
PREVIEW_URL = f"{BASE}/kinoprogram/sept_okt_2026"
VENUE = "Österreichisches Filmmuseum"
ADDRESS = "Augustinerstraße 1, 1010 Wien"
DISTRICT = 1010

ENTRY_RE = re.compile(r'(?=<div class="programm-eintrag">)')
FIELD_RE = re.compile(
    r'<a title="([^"]+)" href="/kinoprogramm/schiene\?schienen_id=(\d+)\s*"'
    r'.*?<div class="programm-datum">([^<]*)</div>'
    r'.*?<h2 class="m-b-0">.*?</h2>'
    r'(?:<h3><a[^>]*>([^<]+)</a></h3>)?'
    r'(.*?)<span class="more-link">',
    re.S,
)


def clean(s):
    if s is None:
        return None
    s = html.unescape(s)
    s = re.sub(r"<[^>]+>", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s or None


def parse_daterange(s, ref_start=None, ref_end=None):
    s = s.strip()
    if not s:
        return None, None
    if re.search(r"jeden\s+dienstag", s, re.I):
        return ref_start, ref_end

    m = re.match(
        r"^(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s+bis\s+(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s+(\d{4})$",
        s)
    if m:
        d1, mo1, d2, mo2, y = m.groups()
        start = f"{y}-{ea.MON[mo1]:02d}-{int(d1):02d}"
        end = f"{y}-{ea.MON[mo2]:02d}-{int(d2):02d}"
        return start, end

    m = re.match(r"^(\d{1,2})\.\s*(?:und|bis)\s*(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s+(\d{4})$", s)
    if m:
        d1, d2, mo, y = m.groups()
        start = f"{y}-{ea.MON[mo]:02d}-{int(d1):02d}"
        end = f"{y}-{ea.MON[mo]:02d}-{int(d2):02d}"
        return start, end

    m = re.match(r"^(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s+(\d{4})$", s)
    if m:
        d, mo, y = m.groups()
        date = f"{y}-{ea.MON[mo]:02d}-{int(d):02d}"
        return date, None

    return None, None


def build(url_title, sid, datum, h3, desc_html):
    title = clean(url_title)
    if not title:
        return None
    start, end = parse_daterange(datum, ref_start="2026-09-01", ref_end="2026-10-22")
    if not start:
        return None
    desc = clean(desc_html)
    return {
        "source": "filmmuseum",
        "source_id": sid,
        "url": f"{BASE}/kinoprogramm/schiene?schienen_id={sid}",
        "title": title,
        "start": start,
        "end": end,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": clean(h3),
        "description": desc,
        "status": "scheduled",
    }


def main():
    page = ea.fetch(PREVIEW_URL)
    records = []
    seen = set()
    for chunk in ENTRY_RE.split(page):
        if "programm-eintrag" not in chunk:
            continue
        m = FIELD_RE.search(chunk)
        if not m:
            continue
        title, sid, datum, h3, desc_html = m.groups()
        if sid in seen:
            continue
        seen.add(sid)
        rec = build(title, sid, datum, h3, desc_html)
        if rec:
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
