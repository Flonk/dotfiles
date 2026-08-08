import html
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://www.tuwien.at"
LIST_URL = BASE + "/en/tu-wien/news/events/page/{}"

ARTICLE_RE = re.compile(
    r'<article class="wpListItem" aria-labelledby="event-(?P<id>\d+)">'
    r'(?P<body>.*?)</article>', re.S)
LINK_RE = re.compile(
    r'<a class="wpListItemEventLink" href="(?P<url>[^"]+)">(?P<title>.*?)</a>', re.S)
DATE_BLOCK_RE = re.compile(
    r'<div class="wpDate (?P<kind>one|two)">.*?<p class="visually-hidden">'
    r'(?P<datetext>.*?)</p>', re.S)
TIME_RE = re.compile(r'(\d{1,2}:\d{2})')
TYPE_RE = re.compile(
    r'Type of event:\s*</span><span class="wpTypeTag">(?P<type>.*?)</span>', re.S)
LOC_RE = re.compile(
    r'Event location:\s*</span><span class="wpLocation">'
    r'(?:<span class="wpLocationIcon"[^>]*></span>)?(?P<loc>.*?)</span>', re.S)
TOTAL_PAGES_RE = re.compile(r'Page \d+ of (\d+)')


def parse_date(s):
    s = html.unescape(s).strip()
    return ea.de_date(s)


def parse_article(m):
    body = m.group("body")
    lm = LINK_RE.search(body)
    if not lm:
        return None
    url = lm.group("url")
    if url.startswith("/"):
        url = BASE + url
    title = ea.text(lm.group("title"))
    title = re.sub(r"^\[Translate to English:\]\s*", "", title or "").strip()

    dm = DATE_BLOCK_RE.search(body)
    start = end = None
    if dm:
        kind = dm.group("kind")
        datetext = html.unescape(dm.group("datetext"))
        if kind == "one":
            parts = [p.strip() for p in datetext.split("until")]
            start_date = parse_date(parts[0])
            wp_time_m = re.search(r'<div class="wpTime">(.*?)</div>', body, re.S)
            start = end = start_date
            if wp_time_m:
                ts = TIME_RE.findall(wp_time_m.group(1))
                if ts and start_date:
                    start = f"{start_date}T{ts[0]}"
                    if len(ts) > 1:
                        end = f"{start_date}T{ts[1]}"
                    else:
                        end = start
        else:
            parts = [p.strip() for p in datetext.split("until")]
            start = parse_date(parts[0]) if parts and parts[0] else None
            end = parse_date(parts[1]) if len(parts) > 1 and parts[1] else None

    tm = TYPE_RE.search(body)
    category = ea.text(tm.group("type")) if tm else None

    locm = LOC_RE.search(body)
    venue = ea.text(locm.group("loc")) if locm else None

    return {
        "source": "tuwien",
        "source_id": f"event-{m.group('id')}",
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": ea.district(venue),
        "city": "Wien",
        "category": category,
    }


def main():
    cutoff = ea.horizon()
    page = 1
    total_pages = None
    seen = set()
    records = []
    while True:
        page_html = ea.fetch(LIST_URL.format(page))
        arts = list(ARTICLE_RE.finditer(page_html))
        if not arts:
            break
        page_min_start = None
        for m in arts:
            rec = parse_article(m)
            if not rec or rec["source_id"] in seen:
                continue
            seen.add(rec["source_id"])
            records.append(rec)
            sd = rec["start"]
            if sd:
                d = sd[:10]
                if page_min_start is None or d < page_min_start:
                    page_min_start = d
        if total_pages is None:
            tp = TOTAL_PAGES_RE.search(page_html)
            total_pages = int(tp.group(1)) if tp else page
        if page >= total_pages:
            break
        if page_min_start and page_min_start > cutoff.isoformat():
            break
        page += 1

    ea.emit(records)


if __name__ == "__main__":
    main()
