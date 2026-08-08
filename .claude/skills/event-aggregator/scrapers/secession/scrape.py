import datetime
import re

import ea

URL = "https://secession.at/category/exhibitions"
VENUE = "Secession"
ADDRESS = "Friedrichstraße 12, 1010 Wien"
DISTRICT = 1010

ITEM_RE = re.compile(
    r'<li class="exhibCatElem">\s*<a href="([^"]+)">'
    r'(.*?)</li>',
    re.S,
)
ARTIST_RE = re.compile(r'exhibSliderArtist">(.*?)</div>', re.S)
WORK_RE = re.compile(r'exhibSliderWork">(.*?)</div>', re.S)
DATE_RE = re.compile(r'exhibSliderDate"[^>]*>(.*?)</div>', re.S)
FULL_DATE = re.compile(r"(\d{1,2})\.(\d{1,2})\.(\d{4})")
PART_DATE = re.compile(r"(\d{1,2})\.(\d{1,2})\.")


def parse_range(raw):
    raw = ea.text(raw) or ""
    parts = re.split(r"[–-]", raw)
    if len(parts) < 2:
        return None, None
    start_raw, end_raw = parts[0].strip(), parts[-1].strip()
    m_end = FULL_DATE.search(end_raw)
    if not m_end:
        return None, None
    end_year = m_end.group(3)
    end = ea.de_date(end_raw)
    if FULL_DATE.search(start_raw):
        start = ea.de_date(start_raw)
    else:
        m_start = PART_DATE.search(start_raw)
        if not m_start:
            return None, end
        year = int(end_year)
        if int(m_start.group(2)) > int(m_end.group(2)):
            year -= 1
        start = ea.de_date(f"{m_start.group(1)}.{m_start.group(2)}.{year}")
    return start, end


def permanent_record():
    today = datetime.date.today().isoformat()
    return {
        "source": "secession",
        "source_id": "beethovenfries",
        "url": "https://secession.at/Beethovenfries",
        "title": "Beethovenfries",
        "start": today,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": None,
        "description": None,
        "status": "scheduled",
        "extra": {"permanent": True},
    }


def main():
    cutoff = ea.horizon()
    page = ea.fetch(URL)

    records = []
    for m in ITEM_RE.finditer(page):
        url, body = m.group(1), m.group(2)
        date_m = DATE_RE.search(body)
        raw_date = date_m.group(1) if date_m else ""
        if "permanent" in raw_date.lower():
            continue

        artist_m = ARTIST_RE.search(body)
        work_m = WORK_RE.search(body)
        artist = ea.text(artist_m.group(1)) if artist_m else None
        work = ea.text(work_m.group(1)) if work_m else None

        start, end = parse_range(raw_date)
        if not start:
            continue

        if artist and work:
            title = f"{artist} – {work}"
        elif work:
            title = work
        elif artist:
            title = artist
        else:
            continue

        source_id = url.rstrip("/").rsplit("/", 1)[-1]

        records.append({
            "source": "secession",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": None,
            "status": "scheduled",
        })

    records.append(permanent_record())
    ea.emit(records)


if __name__ == "__main__":
    main()
