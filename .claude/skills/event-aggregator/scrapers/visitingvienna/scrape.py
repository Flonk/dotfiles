import datetime
import html
import re

import ea

URL = "https://www.visitingvienna.com/entertainment/events/film-festivals/"

DATE_RE = re.compile(
    r"([A-Z][a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?"
    r"(?:\s*(?:to|-|–)\s*(?:([A-Z][a-z]+)\s+)?(\d{1,2})(?:st|nd|rd|th)?)?"
    r",\s*(\d{4})")

HEAD_RE = re.compile(r"<h([234])(?:\s+id=\"([^\"]+)\")?[^>]*>(.*?)</h\1>", re.S)
A_RE = re.compile(r"<a\s[^>]*href=\"([^\"]+)\"", re.I)


def parse_range(s):
    m = DATE_RE.search(s)
    if not m:
        return None, None
    mon1, day1, mon2, day2, year = m.groups()
    mo1 = ea.MON.get(mon1) or ea.MON.get(mon1[:3])
    if not mo1:
        return None, None
    year = int(year)
    start = f"{year:04d}-{mo1:02d}-{int(day1):02d}"
    if day2:
        mo2 = ea.MON.get(mon2) or ea.MON.get(mon2[:3]) if mon2 else mo1
        if not mo2:
            mo2 = mo1
        end = f"{year:04d}-{mo2:02d}-{int(day2):02d}"
    else:
        end = None
    return start, end


def main():
    page = ea.fetch(URL)

    art = re.search(r'<article\b.*?</article>', page, re.S)
    if not art:
        return
    body = art.group(0)

    heads = list(HEAD_RE.finditer(body))
    today = datetime.date.today().isoformat()

    records = []
    for i, m in enumerate(heads):
        level, hid, title_html = m.groups()
        if level != "3" or not hid:
            continue
        title = ea.text(title_html) or hid
        seg_start = m.end()
        seg_end = heads[i + 1].start() if i + 1 < len(heads) else len(body)
        seg_html = body[seg_start:seg_end]

        idx = seg_html.find("Next dates")
        if idx == -1:
            continue
        desc_html = seg_html[:idx]
        after = ea.text(seg_html[idx:idx + 200]) or ""
        after = after.split("Next dates:", 1)[-1].strip()
        if after.startswith("TBA"):
            continue

        start, end = parse_range(after)
        if not start:
            continue
        cmp_date = end or start
        if cmp_date < today:
            continue

        am = A_RE.search(desc_html)
        url = html.unescape(am.group(1)) if am else URL + "#" + hid
        description = ea.text(desc_html)

        records.append({
            "source": "visitingvienna",
            "source_id": hid,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": None,
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
