import datetime
import re
import sys

import ea

BASE = "https://www.filmarchiv.at"
UA = ea.UA

DE_WEEKDAY_MONTHS = {
    "Jän": 1, "Jan": 1, "Feb": 2, "Mär": 3, "Apr": 4, "Mai": 5, "Jun": 6,
    "Jul": 7, "Aug": 8, "Sep": 9, "Okt": 10, "Nov": 11, "Dez": 12,
}

VENUE_DISTRICT = {
    "Metro Kinokulturhaus": (1010, "Johannesgasse 4, 1010 Wien"),
    "Naturarena Open Air": (1020, "Obere Augartenstraße 1, 1020 Wien"),
    "Atrium Open Air": (1020, "Obere Augartenstraße 1, 1020 Wien"),
}


def find_film_ids(days_ahead, cutoff):
    today = datetime.date.today()
    ids = set()
    empty_run = 0
    d = today
    n = 0
    while d <= cutoff and n < days_ahead:
        url = f"{BASE}/?day={d.isoformat()}"
        try:
            page = ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"day fetch failed {d}: {e}\n")
            d += datetime.timedelta(days=1)
            n += 1
            continue
        found = set(re.findall(r'/de/kino/film/(sc_[A-Za-z0-9]+)', page))
        if found:
            empty_run = 0
            ids |= found
        else:
            empty_run += 1
        d += datetime.timedelta(days=1)
        n += 1
        if empty_run >= 10 and ids:
            break
    return ids


def parse_meta_block(chunk):
    out = {}
    for m in re.finditer(
            r'<strong[^>]*>([^:<]+):</strong>\s*<span[^>]*>(.*?)</span>',
            chunk, re.S):
        key = m.group(1).strip()
        val = ea.text(m.group(2))
        out[key] = val
    return out


def resolve_date(day_month_str, ref):
    m = re.match(r"[A-Za-zÄÖÜäöü]{2},\s*(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]{3,4})\.?\s*(\d{1,2}):(\d{2})",
                 day_month_str)
    if not m:
        return None
    day = int(m.group(1))
    mon = DE_WEEKDAY_MONTHS.get(m.group(2))
    if not mon:
        return None
    hh, mm = int(m.group(3)), int(m.group(4))
    year = ref.year
    candidate = datetime.date(year, mon, day)
    if (candidate - ref).days < -180:
        candidate = datetime.date(year + 1, mon, day)
    elif (candidate - ref).days > 180:
        candidate = datetime.date(year - 1, mon, day)
    return f"{candidate.isoformat()}T{hh:02d}:{mm:02d}"


def parse_film(film_id):
    url = f"{BASE}/de/kino/film/{film_id}"
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"film fetch failed {film_id}: {e}\n")
        return []

    tm = re.search(r'<title-div[^>]*>(.*?)</title-div>', page, re.S)
    title = ea.text(tm.group(1)) if tm else None
    if not title:
        return []

    sm = re.search(r'<subtitle-div[^>]*>(.*?)</subtitle-div>', page, re.S)
    subtitle = ea.text(sm.group(1)) if sm else None
    if subtitle and subtitle.lower() != title.lower():
        full_title = f"{title} — {subtitle.title()}"
    else:
        full_title = title

    dm = re.search(
        r'<div class="relative px-4 py-3 leading-tight prose text-s20">\s*<p>(.*?)</p>',
        page, re.S)
    description = ea.text(dm.group(1)) if dm else None

    cm = re.search(r'Im Rahmen von:.*?<a[^>]*>\s*(.*?)\s*</a>', page, re.S)
    category = ea.text(cm.group(1)) if cm else None

    metab = re.search(
        r'<div class="space-y-1 text-\[0\.8rem\][^"]*">(.*?)</div>\s*</div>\s*</div>',
        page, re.S)
    extra = parse_meta_block(metab.group(1)) if metab else {}

    starts = [m.start() for m in re.finditer(r'<div class="p-4 border-black', page)]
    if not starts:
        return []
    starts.append(len(page))

    today = datetime.date.today()
    cutoff = ea.horizon()
    records = []
    for i in range(len(starts) - 1):
        row = page[starts[i]:starts[i + 1]]
        dtm = re.search(r'font-bold text-s35">([^<]+)</div>', row)
        if not dtm:
            continue
        raw_dt = re.sub(r"\s+", " ", dtm.group(1)).strip()
        start = resolve_date(raw_dt, today)
        if not start:
            continue
        d = datetime.date.fromisoformat(start[:10])
        if d < today or d > cutoff:
            continue
        venues = re.findall(r'<div>([^<]*)</div>', row)
        venue = venues[0] if venues else None
        room = venues[1] if len(venues) > 1 else None
        district, address = VENUE_DISTRICT.get(venue, (None, None))
        venue_full = f"{venue} ({room})" if venue and room else venue
        tm2 = re.search(r'ticket-checkout/([0-9a-f-]+)', row)
        ticket_id = tm2.group(1) if tm2 else None
        source_id = ticket_id or f"{film_id}-{start}"
        rec = {
            "source": "filmarchiv",
            "source_id": source_id,
            "url": url,
            "title": full_title,
            "start": start,
            "end": None,
            "venue": venue_full,
            "district": district,
            "city": "Wien",
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": description,
            "extra": extra or None,
        }
        records.append(rec)
    return records


def main():
    cutoff = ea.horizon()
    film_ids = find_film_ids(days_ahead=60, cutoff=cutoff)
    sys.stderr.write(f"found {len(film_ids)} film ids\n")
    records = []
    seen = set()
    for fid in sorted(film_ids):
        for rec in parse_film(fid):
            key = (rec["source"], rec["source_id"])
            if key in seen:
                continue
            seen.add(key)
            records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
