import datetime
import re

import ea

BASE = "https://www.gartenbaukino.at"
OVERVIEW = BASE + "/programm/programmuebersicht/"
VENUE = "Gartenbaukino"
ADDRESS = "Parkring 12, 1010 Wien"
DISTRICT = 1010

PRG_RE = re.compile(
    r'PrgID=(\d+)"[^>]*><time datetime="(\d{4}-\d{2}-\d{2} \d{2}:\d{2})"')
PRICE_RE = re.compile(
    r'(?:Normalpreis|Einheitspreis[^€]*)\s*€\s*(\d+(?:[.,]\d{1,2})?)', re.I)


def prg_map(html):
    out = {}
    for pid, dt in PRG_RE.findall(html):
        out[dt.replace(" ", "T") + ":00"] = pid
    return out


def detail_price(url, cache):
    try:
        html = ea.fetch(url, cache=cache, timeout=60)
    except Exception:
        return None, None
    m = PRICE_RE.search(html)
    if not m:
        return None, None
    raw = m.group(1)
    val = raw.replace(",", ".")
    try:
        return float(val), f"€ {raw}.-"
    except ValueError:
        return None, None


def main():
    html = ea.fetch(OVERVIEW, timeout=60)
    prgids = prg_map(html)
    events = [r for r in ea.jsonld(html) if r.get("@type") == "Event"]

    price_cache = {}
    cutoff = ea.horizon()
    now = datetime.datetime.now()
    records = []
    for e in events:
        start_raw = e.get("startDate")
        if not start_raw:
            continue
        start = start_raw[:16]
        try:
            start_dt = datetime.datetime.strptime(start, "%Y-%m-%dT%H:%M")
        except ValueError:
            continue
        if start_dt < now or start_dt.date() > cutoff:
            continue
        url = e.get("url") or OVERVIEW
        if url not in price_cache:
            price_cache[url] = detail_price(url, cache=None)
        price_min, price_text = price_cache[url]
        prg = prgids.get(start_raw)
        slug = url.rstrip("/").rsplit("/", 1)[-1]
        source_id = f"prg-{prg}" if prg else f"{slug}-{start}"
        extra = {}
        if e.get("videoFormat"):
            extra["video_format"] = e["videoFormat"]
        records.append({
            "source": "gartenbaukino",
            "source_id": source_id,
            "url": url,
            "title": ea.text(e.get("name")),
            "start": start,
            "end": None,
            "image": e.get("image") or None,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": price_min,
            "price_text": price_text,
            "category": None,
            "description": ea.text(e.get("description")),
            "status": "scheduled",
            "extra": extra or None,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
