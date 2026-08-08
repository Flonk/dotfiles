import datetime
import re
import sys

import ea

URL = "https://slashfilmfestival.com/"
INFOS_URL = "https://slashfilmfestival.com/infos/"

MONTH_RE = r"[A-Za-zÄÖÜäöü]+"
DATE_RANGE_RE = re.compile(
    r"(\d{1,2})\.\s*(?:(" + MONTH_RE + r")\.?\s*)?[–-]\s*"
    r"(\d{1,2})\.\s*(" + MONTH_RE + r")\s*(\d{4})"
)

VENUE_NAMES = [
    "Gartenbaukino",
    "Filmcasino",
    "Metro Kinokulturhaus & Festivalzentrum",
    "Club Celeste",
]


def slugify(s):
    s = s.lower()
    s = s.replace("ü", "ue").replace("ö", "oe").replace("ä", "ae").replace("ß", "ss")
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s


def main():
    infos_page = ea.fetch(INFOS_URL)
    infos_text = ea.text(infos_page)
    if not infos_text:
        return

    home_page = ea.fetch(URL)
    home_text = ea.text(home_page) or ""
    tag_m = re.search(r"»([^»«]+)«", home_text)
    description = tag_m.group(1).strip() if tag_m else None

    venues_present = [v for v in VENUE_NAMES if v in infos_text]
    venue = ", ".join(venues_present) if venues_present else None

    today = datetime.date.today().isoformat()

    records = []
    prev_end = 0
    for m in DATE_RANGE_RE.finditer(infos_text):
        title_chunk = infos_text[prev_end:m.start()].strip()
        prev_end = m.end()
        title_m = re.search(r"([\wÄÖÜäöüß½.\s]+?)$", title_chunk)
        name = title_m.group(1).strip() if title_m else None
        if not name:
            continue
        if name.lower() in ("infos", "spielorte"):
            continue

        day1, mon1, day2, mon2, year = m.groups()
        month2 = ea.MON.get(mon2) or ea.MON.get(mon2[:3])
        if not month2:
            continue
        month1 = ea.MON.get(mon1) or ea.MON.get(mon1[:3]) if mon1 else month2
        if not month1:
            month1 = month2
        year = int(year)
        start = f"{year:04d}-{month1:02d}-{int(day1):02d}"
        end = f"{year:04d}-{month2:02d}-{int(day2):02d}"

        if end < today:
            continue

        source_id = f"slashfilmfestival-{slugify(name)}-{year}"
        records.append({
            "source": "slashfilmfestival",
            "source_id": source_id,
            "url": URL,
            "title": name,
            "start": start,
            "end": end,
            "venue": venue,
            "district": None,
            "city": "Wien",
            "address": None,
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": description,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
