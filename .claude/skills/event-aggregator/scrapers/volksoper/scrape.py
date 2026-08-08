import datetime
import os
import re
import sys
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

SLUG = "volksoper"
BASE = "https://www.volksoper.at"

MONTH_NAMES = {
    1: "jänner", 2: "februar", 3: "märz", 4: "april", 5: "mai", 6: "juni",
    7: "juli", 8: "august", 9: "september", 10: "oktober", 11: "november",
    12: "dezember",
}

ARTICLE_RE = re.compile(r"<article\b.*?</article>", re.S)
URL_RE = re.compile(r'href="(https://www\.volksoper\.at/produktion/[^"]+)"')
TITLE_RE = re.compile(r'<h2 class="event-title" itemprop="name">([^<]*)</h2>')
DESC_RE = re.compile(r'<p class="event-description">([^<]*)</p>')
LOC_RE = re.compile(r'event-location">([^<]*)')
START_RE = re.compile(r'itemprop="startDate"\s+content="([^"]+)"')
END_RE = re.compile(r'itemprop="endDate"\s+content="([^"]+)"')
PRICE_RE = re.compile(r'<span class="event-price">\s*([^<]*?)\s*</span>')
ID_RE = re.compile(r"\.(\d+)\.de\.html$")


def month_range(start, end):
    y, m = start.year, start.month
    while (y, m) <= (end.year, end.month):
        yield y, m
        m += 1
        if m > 12:
            m = 1
            y += 1


def parse_month(page, cutoff):
    out = []
    for art in ARTICLE_RE.findall(page):
        um = URL_RE.search(art)
        if not um:
            continue
        url = um.group(1)
        tm = TITLE_RE.search(art)
        title = ea.text(tm.group(1)) if tm else None
        if not title:
            continue
        sm = START_RE.search(art)
        if not sm:
            continue
        start_dt = sm.group(1)[:16].replace(" ", "T")
        start_date = start_dt[:10]
        if start_date < cutoff:
            continue
        em = END_RE.search(art)
        end_dt = em.group(1)[:16].replace(" ", "T") if em else None
        dm = DESC_RE.search(art)
        desc = ea.text(dm.group(1)) if dm else None
        lm = LOC_RE.search(art)
        venue = ea.text(lm.group(1)) if lm else "Volksoper"
        pm = PRICE_RE.search(art)
        price_text = ea.text(pm.group(1)) if pm and pm.group(1).strip() else None
        idm = ID_RE.search(url)
        source_id = idm.group(1) if idm else url
        out.append({
            "source": SLUG,
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start_dt if "T" in start_dt else start_date,
            "end": end_dt if end_dt and end_dt != start_dt else None,
            "venue": venue,
            "district": 1090,
            "city": "Wien",
            "price_min": None,
            "price_text": price_text,
            "category": None,
            "description": desc,
            "extra": {},
        })
    return out


def main():
    today = datetime.date.today()
    cutoff_date = ea.horizon()
    seen = set()
    total = 0
    for y, m in month_range(today, cutoff_date):
        slug = f"{MONTH_NAMES[m]}-{y}"
        url = f"{BASE}/spielplan/{urllib.parse.quote(slug)}.de.html"
        try:
            page = ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"skip {url}: {e}\n")
            continue
        recs = parse_month(page, today.isoformat())
        batch = []
        for r in recs:
            key = (r["source_id"], r["start"])
            if key in seen:
                continue
            seen.add(key)
            batch.append(r)
        total += ea.emit(batch)
    sys.stderr.write(f"total emitted {total}\n")


if __name__ == "__main__":
    main()
