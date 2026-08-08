import datetime
import json
import re
import urllib.request

import ea

SLUG = "hdgoe"
BASE = "https://hdgoe.at"
VENUE = "Haus der Geschichte Österreich"
DISTRICT = 1010
ADDRESS = "Neue Hofburg, Heldenplatz, 1010 Wien"

# Only the categories the site itself surfaces in the calendar legend/filter UI.
# Others seen on the raw API (cat 0, 9, 20) are English-duplicate rows and admin
# "opening hours changed" notices, not real listed occurrences.
CATS = {
    "81": "Führungen",
    "143": "Kinder- & Jugendprogramm",
    "147": "Veranstaltungen",
}

EXHIBIT_ITEM = re.compile(
    r'<a href="(?P<url>[^"]+)">\s*<div class="category_list_item[^"]*"[^>]*>\s*'
    r'<img[^>]*/>\s*<div class="list_item_author">[^<]*</div>\s*'
    r'<div class="list_item_title">\s*(?P<title>.*?)</div>\s*'
    r'<div class="list_item_teaser">\s*(?P<teaser>.*?)</div>',
    re.S)

DATE_RANGE = re.compile(
    r'(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*\d{0,4})\s*[–-]\s*'
    r'(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*\d{4})')
AB_DATE = re.compile(r'\bAb\s+(\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*\d{4})')

MODULE_TEXT = re.compile(r'class="module module_text "[^>]*>(.*?)</div>', re.S)


def admission_price():
    html = ea.fetch(BASE + "/zeiten-preise")
    txt = ea.text(html) or ""
    m = re.search(r"Erwachsene\s*€\s*(\d+(?:[.,]\d+)?)", txt)
    if m:
        return float(m.group(1).replace(",", ".")), f"Erwachsene € {m.group(1)}"
    return None, None


def detail_text(url, cache):
    if url in cache:
        return cache[url]
    html = ea.fetch(url)
    desc = None
    for m in MODULE_TEXT.finditer(html):
        t = ea.text(m.group(1))
        if t:
            desc = t
            break
    cache[url] = desc
    return desc


def exhibitions(price_min, price_text, today, desc_cache):
    html = ea.fetch(BASE + "/category/kalender")
    m = re.search(r'currentProgramElemHolder.*?(?=<style>)', html, re.S)
    block = m.group(0) if m else html
    out = []
    for em in EXHIBIT_ITEM.finditer(block):
        url = em.group("url")
        title = ea.text(em.group("title"))
        teaser = ea.text(em.group("teaser")) or ""
        description = detail_text(url, desc_cache)
        haystack = teaser + " " + (description or "")
        rng = DATE_RANGE.search(haystack)
        ab = AB_DATE.search(haystack)
        permanent = False
        end = None
        if rng:
            end_m = re.search(r"\d{4}", rng.group(2))
            year = end_m.group(0) if end_m else None
            start = ea.de_date(rng.group(1), default_year=year)
            end = ea.de_date(rng.group(2))
        elif ab:
            start = ea.de_date(ab.group(1))
            permanent = True
        else:
            start = today
            permanent = True
        if not start:
            continue
        rec = {
            "source": SLUG,
            "source_id": url.rstrip("/").rsplit("/", 1)[-1],
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": price_min,
            "price_text": price_text,
            "category": "Ausstellung",
            "description": description or teaser or None,
        }
        if permanent:
            rec["extra"] = {"permanent": True}
        out.append(rec)
    return out


def main():
    today = datetime.date.today().isoformat()
    cutoff = ea.horizon()

    price_min, price_text = admission_price()
    desc_cache = {}
    records = exhibitions(price_min, price_text, today, desc_cache)

    monday = datetime.date.today() - datetime.timedelta(days=datetime.date.today().weekday())
    week = monday
    while week <= cutoff:
        req = urllib.request.Request(
            BASE + "/Frontend/load_calendar_events",
            data=f"start={week.isoformat()}".encode(),
            headers={"User-Agent": ea.UA})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = json.loads(r.read().decode("utf-8", "replace"))
        for ev in data.get("events", []):
            cat_id = str(ev.get("cat_id"))
            if cat_id not in CATS:
                continue
            start_raw = ev.get("start") or ""
            m = re.match(r"(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})", start_raw)
            if not m:
                continue
            start = f"{m.group(1)}-{m.group(2)}-{m.group(3)}T{m.group(4)}:{m.group(5)}"
            if start[:10] < today:
                continue
            pretty_url = ev.get("pretty_url") or ""
            url = f"{BASE}/{pretty_url}"
            title = ea.text(ev.get("title")) or ""
            description = detail_text(url, desc_cache)
            records.append({
                "source": SLUG,
                "source_id": str(ev.get("id") or f"{pretty_url}-{start}"),
                "url": url,
                "title": title,
                "start": start,
                "end": None,
                "venue": VENUE,
                "district": DISTRICT,
                "city": "Wien",
                "address": ADDRESS,
                "price_min": 0.0 if cat_id == "147" else None,
                "price_text": "kostenlos" if cat_id == "147" else None,
                "category": CATS[cat_id],
                "description": description,
            })
        week += datetime.timedelta(days=7)

    ea.emit(records)


if __name__ == "__main__":
    main()
