import datetime
import re
import urllib.error

import ea

BASE = "https://www.fluc.at/programm/"
VENUE_ADDRESS = "Praterstern 5, 1020 Wien"
VENUE_DISTRICT = 1020

NOISE_PREFIXES = ("abgesagt", "ev.", "event.", "fixiert:", "#")

DAY_RE = re.compile(
    r"<li class='datum' id='d_(\d{8})'\s*>.*?<ul class='info' id='i_\1'\s*>(.*?)</ul>\s*</li>",
    re.S)
CELL_F_RE = re.compile(r"<li class='fluc[^']*' id='f_\d{8}'>(.*?)</li>", re.S)
CELL_W_RE = re.compile(r"<li class='[^']*wanne[^']*' id='w_\d{8}'>(.*?)</li>", re.S)
TIME_RANGE_RE = re.compile(
    r"(?<![\d.])\b([01]?\d|2[0-3])[:.](\d{2})\s*(?:-|bis)\s*([01]?\d|2[0-3])[:.](\d{2})\b")
TIME_RE = re.compile(r"(?<![\d.])\b([01]?\d|2[0-3])[:.](\d{2})\b")


def strip_noise(title):
    changed = True
    while changed:
        changed = False
        for p in NOISE_PREFIXES:
            t = title.strip()
            if t.lower().startswith(p):
                t = t[len(p):].strip(" :- ")
                if t != title:
                    title = t
                    changed = True
    return title.strip(" :- ")


def parse_cell(raw):
    cell = re.sub(r"<small>.*?</small>", " ", raw, flags=re.S)
    cancelled = bool(re.search(r"abgesagt", cell, re.I))
    plain = ea.text(cell)
    if not plain:
        return None
    if plain.strip(" ; ") == "":
        return None

    mrange = TIME_RANGE_RE.search(plain)
    start_time = end_time = None
    if mrange:
        start_time = f"{int(mrange.group(1)):02d}:{mrange.group(2)}"
        end_time = f"{int(mrange.group(3)):02d}:{mrange.group(4)}"
        title_raw = plain[:mrange.start()] + " " + plain[mrange.end():]
    else:
        mt = TIME_RE.search(plain)
        if mt:
            start_time = f"{int(mt.group(1)):02d}:{mt.group(2)}"
            title_raw = plain[:mt.start()] + " " + plain[mt.end():]
        else:
            title_raw = plain

    title_raw = re.sub(r"\s+", " ", title_raw).strip()
    title_raw = re.sub(r":\s*:", ":", title_raw)
    title_raw = title_raw.lstrip(" :-")
    title = strip_noise(title_raw)
    if not title:
        title = strip_noise(re.sub(r"\s+", " ", plain).strip())
    if not title:
        return None

    return title, start_time, end_time, cancelled


def week_url(d):
    iso = d.isocalendar()
    return f"{BASE}{iso.year}_Flucwoche{iso.week:02d}.html"


def fetch_week(d):
    url = week_url(d)
    try:
        return ea.fetch(url), url
    except urllib.error.HTTPError:
        return None, url


def main():
    today = datetime.date.today()
    cutoff = ea.horizon()

    monday = today - datetime.timedelta(days=today.weekday())
    records = []
    seen = set()

    weeks_done = 0
    while monday <= cutoff and weeks_done < 60:
        page, url = fetch_week(monday)
        weeks_done += 1
        monday += datetime.timedelta(days=7)
        if not page:
            continue

        for m in DAY_RE.finditer(page):
            day_str, block = m.group(1), m.group(2)
            try:
                day = datetime.datetime.strptime(day_str, "%Y%m%d").date()
            except ValueError:
                continue
            if day < today or day.year < 2020:
                continue

            for cell_re, venue in ((CELL_F_RE, "Fluc"), (CELL_W_RE, "Fluc Wanne")):
                cm = cell_re.search(block)
                if not cm:
                    continue
                parsed = parse_cell(cm.group(1))
                if not parsed:
                    continue
                title, start_time, end_time, cancelled = parsed

                start = f"{day.isoformat()}T{start_time}" if start_time else day.isoformat()
                end = f"{day.isoformat()}T{end_time}" if end_time else None

                sid = f"{day.isoformat()}-{venue.lower().replace(' ', '_')}"
                if sid in seen:
                    continue
                seen.add(sid)

                records.append({
                    "source": "fluc",
                    "source_id": sid,
                    "url": url,
                    "title": title,
                    "start": start,
                    "end": end,
                    "venue": venue,
                    "district": VENUE_DISTRICT,
                    "city": "Wien",
                    "address": VENUE_ADDRESS,
                    "price_min": None,
                    "price_text": None,
                    "category": None,
                    "description": None,
                    "status": "cancelled" if cancelled else "scheduled",
                    "extra": None,
                })

    ea.emit(records)


if __name__ == "__main__":
    main()
