import re

import ea

BASE = "https://www.literaturhaus-wien.at"
LIST_URL = BASE + "/programm/veranstaltungen/"
PAGE_URL = BASE + "/programm/veranstaltungen/seite/{n}/"
VENUE = "Literaturhaus Wien"
DISTRICT = 1070
ADDRESS = "Zieglergasse 26A, 1070 Wien"

EVENT_RE = re.compile(
    r'<a class="item-scope" href="([^"]+)">.*?'
    r'<div class="date-info">(.*?)</div>\s*'
    r'<div class="title">(.*?)</div>',
    re.S)
TAG_BLOCK_RE = re.compile(r'<div class="tag">([^<]*)</div>')
DESC_RE = re.compile(r'<div class="content-area">\s*<p>\s*(.*?)\s*</p>', re.S)


def parse_block(block):
    m = EVENT_RE.search(block)
    if not m:
        return None
    url, date_raw, title_raw = m.group(1), m.group(2), m.group(3)
    title = ea.text(title_raw)
    if not title:
        return None

    date_raw = ea.text(date_raw)
    start = end = None
    if date_raw and " - " in date_raw:
        left, right = date_raw.split(" - ", 1)
        start, end = ea.de_date(left), ea.de_date(right)
    elif date_raw:
        start = ea.de_date(date_raw)

    tags = TAG_BLOCK_RE.findall(block)
    tags = [ea.text(t) for t in tags]
    category = ", ".join(tags) if tags else None

    desc_m = DESC_RE.search(block)
    description = ea.text(desc_m.group(1)) if desc_m else None

    return {
        "source": "literaturhaus",
        "source_id": url,
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": category,
        "description": description,
        "status": "scheduled",
        "extra": {"tags": tags} if tags else None,
    }


def fetch_page(n):
    url = LIST_URL if n == 1 else PAGE_URL.format(n=n)
    return ea.fetch(url)


def main():
    horizon = ea.horizon().isoformat()
    recs = []
    n = 1
    seen_urls = set()
    while True:
        page = fetch_page(n)
        blocks = page.split('<div class="event">')[1:]
        if not blocks:
            break
        got_any = False
        page_last_start = None
        for block in blocks:
            rec = parse_block(block)
            if not rec or not rec["start"]:
                continue
            if rec["url"] in seen_urls:
                continue
            seen_urls.add(rec["url"])
            got_any = True
            page_last_start = rec["start"]
            recs.append(rec)
        has_next = f'seite/{n + 1}/' in page
        if not has_next or not got_any:
            break
        if page_last_start and page_last_start[:10] > horizon:
            break
        n += 1
        if n > 20:
            break

    ea.emit(recs)


if __name__ == "__main__":
    main()
