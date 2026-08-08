import re

import ea

BASE = "https://talks-calendar.ista.ac.at"
EVENT_URL = "https://talks-calendar.ista.ac.at/events/{id}"

ROW_RE = re.compile(
    r'<a class="link" href="/events/(\d+)">(.*?)</a>.*?'
    r'<td>\s*<b>.*?</b>.*?</td>\s*<td>(.*?)</td>\s*<td\s*nowrap>(.*?)</td>',
    re.S)

VEVENT_RE = re.compile(r'BEGIN:VEVENT(.*?)END:VEVENT', re.S)
FIELD_RE = re.compile(r'^([A-Z]+):(.*)$')


def unfold(text):
    lines = text.replace("\r\n", "\n").split("\n")
    out = []
    for line in lines:
        if line.startswith((" ", "\t")) and out:
            out[-1] += line[1:]
        else:
            out.append(line)
    return out


def ics_unescape(s):
    return (s or "").replace("\\,", ",").replace("\\;", ";").replace("\\n", "\n").replace("\\\\", "\\")


def parse_ics_dt(s):
    m = re.match(r"(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})", s)
    if not m:
        return None
    y, mo, d, h, mi = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
    return f"{y}-{mo}-{d}T{h}:{mi}"


def parse_ics(text):
    out = {}
    for block in VEVENT_RE.findall(text):
        fields = {}
        for line in unfold(block):
            m = FIELD_RE.match(line)
            if not m:
                continue
            key, val = m.group(1), m.group(2)
            fields[key] = val
        url = fields.get("URL", "")
        idm = re.search(r'/events/(\d+)', url)
        if not idm:
            continue
        eid = idm.group(1)
        out[eid] = {
            "start": parse_ics_dt(fields.get("DTSTART", "")),
            "end": parse_ics_dt(fields.get("DTEND", "")),
            "summary": ics_unescape(fields.get("SUMMARY")),
            "description": ics_unescape(fields.get("DESCRIPTION")),
            "location": ics_unescape(fields.get("LOCATION")),
            "url": url,
        }
    return out


def parse_table(page):
    out = {}
    for m in ROW_RE.finditer(page):
        eid, title, series, start_txt = m.groups()
        out[eid] = {
            "title": ea.text(title),
            "series": ea.text(series) or None,
        }
    return out


def main():
    table_page = ea.fetch(f"{BASE}/events")
    ics_text = ea.fetch(f"{BASE}/generate_all_ics")

    rows = parse_table(table_page)
    events = parse_ics(ics_text)

    horizon = ea.horizon().isoformat()

    records = []
    for eid, ev in events.items():
        if not ev["start"]:
            continue
        if ev["start"][:10] > horizon:
            continue
        row = rows.get(eid, {})
        title = row.get("title") or ev["summary"]
        if not title:
            continue

        district, city, address = None, None, None
        loc = ev["location"]
        if loc:
            district = ea.district(loc)
            city = "Wien" if district else None
            address = loc

        records.append({
            "source": "ista",
            "source_id": eid,
            "url": ev["url"] or EVENT_URL.format(id=eid),
            "title": title,
            "start": ev["start"],
            "end": ev["end"],
            "venue": loc,
            "district": district,
            "city": city,
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": row.get("series"),
            "description": ev["description"],
            "status": "scheduled",
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
