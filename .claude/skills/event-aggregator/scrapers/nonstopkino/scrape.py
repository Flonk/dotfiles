import datetime
import re
import sys

import ea

BASE = "https://nonstopkino.at"
LIST_URL = f"{BASE}/events/"

ARTICLE_RE = re.compile(
    r'<article class="event" id="([^"]+)"[^>]*data-date="(\d{8})"[^>]*>(.*?)</article>',
    re.S)
HREF_RE = re.compile(r'<a href="([^"]+)">')
TITLE_RE = re.compile(r'<h2>(.*?)</h2>', re.S)
LOCATION_RE = re.compile(r'<div class="location">(.*?)</div>', re.S)
TAG_RE = re.compile(r'<div class="highlight-tag"[^>]*>(.*?)</div>', re.S)

DETAIL_DATE_RE = re.compile(
    r'<p class="date">.*?<span class="value">(.*?)</span>', re.S)
DETAIL_LOC_RE = re.compile(
    r'<p class="location">.*?<span class="value">(.*?)</span>', re.S)
DETAIL_DESC_RE = re.compile(r'<div class="intro-text">\s*<p>(.*?)</p>', re.S)

TIME_RE = re.compile(r'(\d{1,2}):(\d{2})')
DAY_LIST_RE = re.compile(
    r'^(?P<days>(?:\d{1,2}\.,?\s*(?:und\s*)?)+)(?P<month>\d{1,2})\.(?P<year>\d{4})$')
DAY_RE = re.compile(r'(\d{1,2})\.')


def parse_dates(text, fallback_iso):
    text = ea.text(text) or ""
    m = DAY_LIST_RE.match(text)
    if m:
        days = [int(d) for d in DAY_RE.findall(m.group("days"))]
        mo, yy = int(m.group("month")), int(m.group("year"))
        out = []
        for d in days:
            try:
                out.append(f"{yy:04d}-{mo:02d}-{d:02d}")
            except ValueError:
                continue
        if out:
            return out
    return [fallback_iso]


def main():
    html = ea.fetch(LIST_URL, cache=None, timeout=60)
    cutoff = ea.horizon()
    today = datetime.date.today()

    events = []
    for m in ARTICLE_RE.finditer(html):
        eid, ymd, body = m.groups()
        href_m = HREF_RE.search(body)
        if not href_m:
            continue
        url = href_m.group(1)
        title_m = TITLE_RE.search(body)
        title = ea.text(title_m.group(1)) if title_m else eid.replace("-", " ").title()
        loc_m = LOCATION_RE.search(body)
        location = ea.text(loc_m.group(1)) if loc_m else None
        if location and re.search(r"\bGraz\b", location):
            continue
        tag_m = TAG_RE.search(body)
        category = ea.text(tag_m.group(1)) if tag_m else None

        try:
            d = datetime.date(int(ymd[:4]), int(ymd[4:6]), int(ymd[6:8]))
        except ValueError:
            continue
        if d < today or d > cutoff:
            continue

        events.append({
            "id": eid, "url": url, "title": title,
            "location": location, "category": category, "fallback": ymd,
        })

    records = []
    for ev in events:
        try:
            dhtml = ea.fetch(ev["url"], timeout=60)
        except Exception as e:
            sys.stderr.write(f"fetch failed {ev['url']}: {e}\n")
            dhtml = None

        fallback_iso = f"{ev['fallback'][:4]}-{ev['fallback'][4:6]}-{ev['fallback'][6:8]}"
        date_text, loc_text, desc = None, None, None
        if dhtml:
            dm = DETAIL_DATE_RE.search(dhtml)
            date_text = dm.group(1) if dm else None
            lm = DETAIL_LOC_RE.search(dhtml)
            loc_text = ea.text(lm.group(1)) if lm else None
            dm2 = DETAIL_DESC_RE.search(dhtml)
            desc = ea.text(dm2.group(1)) if dm2 else None

        time_hhmm = None
        if date_text:
            tm = TIME_RE.search(date_text)
            if tm:
                time_hhmm = f"{int(tm.group(1)):02d}:{tm.group(2)}"
            dates = parse_dates(date_text, fallback_iso)
        else:
            dates = [fallback_iso]

        district = ea.district(ev["location"]) if ev["location"] else None
        venue = loc_text or ev["location"] or None
        if venue:
            venue = venue.split(",")[0].strip()
        city = "Wien"

        for iso in dates:
            try:
                y, mo, dd = (int(x) for x in iso.split("-"))
                dt = datetime.date(y, mo, dd)
            except ValueError:
                continue
            if dt < today or dt > cutoff:
                continue
            start = f"{iso}T{time_hhmm}" if time_hhmm else iso
            source_id = f"{ev['id']}-{iso}" if len(dates) > 1 else ev["id"]
            records.append({
                "source": "nonstopkino",
                "source_id": source_id,
                "url": ev["url"],
                "title": ev["title"],
                "start": start,
                "end": None,
                "venue": venue,
                "district": district,
                "city": city,
                "address": None,
                "price_min": None,
                "price_text": None,
                "category": ev["category"],
                "description": desc,
                "status": "scheduled",
            })

    ea.emit(records)


if __name__ == "__main__":
    main()
