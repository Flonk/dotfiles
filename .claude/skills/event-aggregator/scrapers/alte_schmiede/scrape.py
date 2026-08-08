import re
import sys

import ea

BASE = "https://alte-schmiede.at"
LIST_URL = f"{BASE}/programm"

VENUE = "Alte Schmiede Kunstverein Wien"
ADDRESS = "Schönlaterngasse 9"
DISTRICT = 1010

DATE_TEST_RE = re.compile(r'date-test="(\d{4}-\d{2}-\d{2}) (\d{2}):(\d{2}):\d{2}"')
TITLE_RE = re.compile(r'<h1 class="event-title[^"]*">(.*?)</h1>', re.S)
HASHTAG_RE = re.compile(r'<h3 class="event-hashtag">\s*(.*?)\s*</h3>', re.S)
INFO_RE = re.compile(
    r'<div class="event-artist-(?:info|bio)">\s*(.*?)\s*</div>', re.S)


def list_slugs():
    page = ea.fetch(LIST_URL, cache="page.html")
    slugs = sorted(set(re.findall(r'href="//alte-schmiede\.at/programm/recital/([^"]+)"', page)))
    return slugs


def parse_detail(slug):
    url = f"{BASE}/programm/recital/{slug}"
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"skip {slug}: {e}\n")
        return None

    dm = DATE_TEST_RE.search(page)
    if not dm:
        return None
    date, hh, mm = dm.groups()
    start = f"{date}T{hh}:{mm}"

    detail_start = page.find('recital-detail single-post')
    body = page[detail_start:] if detail_start != -1 else page

    tm = TITLE_RE.search(body)
    title = ea.text(tm.group(1)) if tm else None
    if not title:
        return None

    hm = HASHTAG_RE.search(body)
    category = ea.text(hm.group(1)) if hm else None

    descs = [ea.text(m.group(1)) for m in INFO_RE.finditer(body)]
    descs = [d for d in descs if d]
    description = " ".join(descs) if descs else None

    return {
        "source": "alte_schmiede",
        "source_id": slug,
        "url": url,
        "title": title,
        "start": start,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": category,
        "description": description,
        "status": "scheduled",
    }


def main():
    cutoff = ea.horizon()
    records = []
    for slug in list_slugs():
        rec = parse_detail(slug)
        if not rec:
            continue
        import datetime
        start_date = datetime.date.fromisoformat(rec["start"][:10])
        if start_date > cutoff:
            continue
        records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
