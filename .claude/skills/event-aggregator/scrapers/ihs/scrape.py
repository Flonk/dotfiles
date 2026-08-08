import re
import sys
import time

import ea

BASE = "https://www.ihs.ac.at"
LIST_URL = f"{BASE}/news-and-events/events-calendar/"

ITEM_RE = re.compile(
    r'<div class="events article">.*?<a itemprop="url" title="[^"]*" href="([^"]+)">'
    r'\s*<span itemprop="headline">(.*?)</span>',
    re.S,
)

DATE_RE = re.compile(
    r'<time itemprop="datePublished" datetime="(\d{4}-\d{2}-\d{2})">'
)
TIME_RE = re.compile(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})')
VENUE_RE = re.compile(
    r'</time>\s*(?:<time[^>]*>.*?</time>)?\s*(.*?)</span>', re.S
)


def parse_list(page):
    out = []
    for m in ITEM_RE.finditer(page):
        href, title = m.group(1), ea.text(m.group(2))
        url = href if href.startswith("http") else BASE + href
        out.append({"url": url, "title": title})
    return out


def parse_detail(page):
    dates = DATE_RE.findall(page)
    start_date = dates[0] if dates else None
    end_date = dates[1] if len(dates) > 1 else None
    if end_date == start_date:
        end_date = None

    tm = TIME_RE.search(page)
    start_time = tm.group(1) if tm else None
    end_time = tm.group(2) if tm else None

    footer_m = re.search(r'<span class="news-list-date">(.*?)</span>', page, re.S)
    venue = None
    if footer_m:
        without_time_tags = re.sub(r'<time[^>]*>.*?</time>', '', footer_m.group(1), flags=re.S)
        remainder = ea.text(without_time_tags) or ""
        remainder = re.sub(r'^\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}\s*,?\s*', '', remainder)
        venue = remainder.strip() or None

    desc = None
    body_m = re.search(r'<div class="ce-bodytext">(.*?)</div>\s*(?:</div>)?\s*(?:<div class="ce-gallery"|$)',
                        page, re.S)
    if body_m:
        desc = ea.text(body_m.group(1))

    start = start_date
    if start and start_time:
        start = f"{start_date}T{start_time}"
    end = end_date
    if end and end_time:
        end = f"{end_date}T{end_time}"
    elif not end and start_date and end_time and end_time != start_time:
        end = f"{start_date}T{end_time}"

    district = ea.district(venue)

    return {
        "start": start,
        "end": end,
        "venue": venue,
        "district": district,
        "description": desc,
    }


def main():
    page = ea.fetch(LIST_URL)
    items = parse_list(page)

    records = []
    for item in items:
        detail_page = None
        for attempt in range(3):
            try:
                detail_page = ea.fetch(item["url"])
                break
            except Exception as e:
                sys.stderr.write(f"{item['url']} attempt {attempt}: {e}\n")
                time.sleep(1)
        if not detail_page:
            continue
        d = parse_detail(detail_page)
        if not d["start"]:
            continue

        source_id = item["url"].rstrip("/").rsplit("/", 1)[-1]

        records.append({
            "source": "ihs",
            "source_id": source_id,
            "url": item["url"],
            "title": item["title"],
            "start": d["start"],
            "end": d["end"],
            "venue": d["venue"],
            "district": d["district"],
            "city": "Wien",
            "address": d["venue"],
            "price_min": None,
            "price_text": None,
            "category": None,
            "description": d["description"],
            "status": "scheduled",
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
