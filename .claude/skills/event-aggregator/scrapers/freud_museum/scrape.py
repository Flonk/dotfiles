import datetime
import html
import re
import urllib.parse

import ea

BASE = "https://www.freud-museum.at/"
PROGRAM_URL = BASE + "de/ausstellungen-programm/programm"
TOURS_URL = BASE + "de/fuehrungstermine"
EXHIBITIONS_URL = BASE + "de/ausstellungen-programm"
VENUE = "Sigmund Freud Museum"
DISTRICT = 1090


def slug_of(url):
    return urllib.parse.urlsplit(url).path.rstrip("/").rsplit("/", 1)[-1]


def clean(s):
    return html.unescape(re.sub(r"<[^>]+>", " ", s or "")).strip() or None


def parse_eventlist(page, source):
    blocks = re.split(r'(?=<div class="event event--teaser)', page)
    records = []
    for b in blocks[1:]:
        m_time = re.search(r'<time class="event__date" datetime="([^"]+)"', b)
        m_link = re.search(
            r'<h3 class="event__title"><a href="([^"]+)"[^>]*>([^<]*)</a></h3>', b)
        if not m_time or not m_link:
            continue
        raw_dt = m_time.group(1)
        start = raw_dt[:16] if len(raw_dt) > 10 and raw_dt[10] == "T" else raw_dt[:10]
        url = BASE + m_link.group(1)
        title = html.unescape(m_link.group(2)).strip()
        m_teaser = re.search(r'<div class="event__teaser"><p>(.*?)</p></div>', b, re.S)
        description = clean(m_teaser.group(1)) if m_teaser else None
        m_loc = re.search(
            r'<p class="event__location">\s*<span>(.*?)</span>', b, re.S)
        venue = clean(m_loc.group(1)) if m_loc else VENUE
        online = bool(venue and "zoom" in venue.lower())
        records.append({
            "source": source,
            "source_id": slug_of(url),
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": None if online else DISTRICT,
            "city": None if online else "Wien",
            "address": None,
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": description,
            "status": "scheduled",
        })
    return records


def parse_exhibitions(page, source, today):
    blocks = re.split(r'(?=<div class="ce_rsce_teaser)', page)
    records = []
    for b in blocks[1:]:
        m_href = re.search(r'<a href="([^"]+)"', b)
        m_title = re.search(
            r'<h3 class="teaser__subheadline">(.*?)</h3>', b, re.S)
        m_text = re.search(
            r'<div class="teaser__text">\s*<p>(.*?)</p>', b, re.S)
        if not m_href or not m_title:
            continue
        url = BASE + m_href.group(1)
        title = html.unescape(clean(m_title.group(1)) or "")
        text = clean(m_text.group(1)) if m_text else None

        start, end, permanent = None, None, False
        m_range = re.search(
            r"(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*\d{4})\s*-\s*"
            r"(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*\d{4})", text or "")
        m_from = re.search(
            r"\bab\s+(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*\d{4})", text or "")
        if m_range:
            start = ea.de_date(m_range.group(1))
            end = ea.de_date(m_range.group(2))
        elif m_from:
            start = ea.de_date(m_from.group(1))
            end = None
            permanent = True
        else:
            start = today
            end = None
            permanent = True
        if not start:
            continue

        rec = {
            "source": source,
            "source_id": slug_of(url),
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": None,
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": text,
            "status": "scheduled",
        }
        if permanent:
            rec["extra"] = {"permanent": True}
        records.append(rec)
    return records


def main():
    source = "freud_museum"
    horizon = ea.horizon().isoformat()
    today = datetime.date.today().isoformat()

    records = []
    records.extend(parse_eventlist(ea.fetch(PROGRAM_URL), source))
    records.extend(parse_eventlist(ea.fetch(TOURS_URL), source))
    records.extend(parse_exhibitions(ea.fetch(EXHIBITIONS_URL), source, today))

    seen = set()
    out = []
    for r in records:
        end = r.get("end")
        permanent = (r.get("extra") or {}).get("permanent")
        if permanent:
            pass
        elif end:
            if end[:10] < today:
                continue
        elif r["start"][:10] < today:
            continue
        if not end and not permanent and r["start"][:10] > horizon:
            continue
        key = (r["source_id"], r["start"])
        if key in seen:
            continue
        seen.add(key)
        out.append(r)

    ea.emit(out)


if __name__ == "__main__":
    main()
