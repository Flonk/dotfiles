import datetime
import re
import sys

import ea

MON = {m: i + 1 for i, m in enumerate(
    "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split())}

BASE = "https://www.wpi.ac.at/"
LIST_URL = BASE + "activities_view.php?printall=2"


def parse_dt(day, mon, year, time_hm):
    d = f"{int(year):04d}-{MON[mon]:02d}-{int(day):02d}"
    if time_hm:
        h, m = time_hm
        d += f"T{int(h):02d}:{int(m):02d}"
    return d


def parse_block(block):
    m = re.search(
        r'<a href="event_view\.php\?id_activity=(\d+)">\s*(.*?)\s*</a>',
        block, re.S)
    if not m:
        return None
    id_activity, title = m.group(1), m.group(2)
    title = title.replace("</b>", "").strip()
    title = ea.text(title)

    loc_m = re.search(r'Location:\s*</b>|Location:\s*(.*?)</b>', block, re.S)
    venue = None
    m2 = re.search(r'Location:\s*(.*?)</b>', block, re.S)
    if m2:
        venue = ea.text(m2.group(1))

    tm = re.search(
        r'Time:\s*(\d{1,2})\.\s*([A-Za-z]{3,})\.?\s*(\d{4})\s*\([^)]*\)\s*-\s*'
        r'(\d{1,2})\.\s*([A-Za-z]{3,})\.?\s*(\d{4})\s*\([^)]*\)'
        r'(?:;\s*Opening:\s*(\d{1,2})[:.](\d{2}))?',
        block, re.S)
    start = end = None
    if tm:
        d1, mo1, y1, d2, mo2, y2, oh, om = tm.groups()
        mo1 = mo1[:3].capitalize()
        mo2 = mo2[:3].capitalize()
        if mo1 in MON and mo2 in MON:
            start = parse_dt(d1, mo1, y1, (oh, om) if oh else None)
            end = parse_dt(d2, mo2, y2, None)

    website = None
    wm = re.search(r'external\s*<a href="([^"]+)">\s*website\s*</a>', block, re.S)
    if wm:
        website = wm.group(1)

    orgs = []
    om = re.search(r'Organisation\(s\)\s*</font>\s*<br>\s*(.*?)</td>', block, re.S)
    if om:
        orgs = [ea.text(x) for x in om.group(1).split("<br>") if ea.text(x)]

    organisers = []
    or_m = re.search(r'Organiser\(s\)\s*</font>\s*<br>\s*(.*?)</td>', block, re.S)
    if or_m:
        organisers = [ea.text(x) for x in or_m.group(1).split("<br>") if ea.text(x)]

    topics = []
    tp_m = re.search(r'Topics:\s*</font>\s*<br>\s*(.*?)</em>', block, re.S)
    if tp_m:
        topics = [ea.text(x) for x in tp_m.group(1).split("<br>") if ea.text(x)]

    extra = {}
    if orgs:
        extra["organisations"] = orgs
    if organisers:
        extra["organisers"] = organisers
    if topics:
        extra["topics"] = topics
    if website:
        extra["external_website"] = website

    return {
        "source": "wpi",
        "source_id": id_activity,
        "url": BASE + f"event_view.php?id_activity={id_activity}",
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": ea.district(venue),
        "city": "Wien",
        "address": None,
        "price_min": None,
        "price_text": None,
        "category": None,
        "description": None,
        "extra": extra or None,
    }


def main():
    page = ea.fetch(LIST_URL, cache="page.html")
    blocks = re.split(r'(?=<table class=bordertable)', page)
    cutoff = ea.horizon()
    records = []
    for b in blocks:
        if 'event_view.php?id_activity=' not in b:
            continue
        rec = parse_block(b)
        if not rec or not rec["start"]:
            continue
        try:
            start_date = datetime.date.fromisoformat(rec["start"][:10])
        except ValueError:
            continue
        if start_date > cutoff:
            continue
        records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
