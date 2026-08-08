import re
import sys

sys.path.insert(0, "../lib")
import ea

BASE = "https://www.vienna-marathon.com/"
EVENTS_URL = BASE + "?go=events"


def strip_comments(s):
    return re.sub(r"<!--.*?-->", "", s, flags=re.S)


def extract_price(detail_html):
    m = re.search(r"Teilnahmebeitrag[^<]*</h3>(.*?)</ul>", detail_html, re.S)
    if not m:
        return None, None
    return ea.price(m.group(1))


def main():
    page = ea.fetch(EVENTS_URL)
    records = []
    for block in page.split('<div class="row nomargin">')[1:]:
        hm = re.search(r'<h4 class="center space-40">([^<]+)</h4>', block)
        header_date = hm.group(1) if hm else None
        start = ea.de_date(header_date) if header_date else None
        clean = strip_comments(block)
        for card in re.split(r'<div[^>]*class="card h-100 boxshadow">', clean)[1:]:
            gm = re.search(r'\?go=(\w+)"', card)
            if not gm:
                continue
            slug = gm.group(1)
            if "registration_options" not in card:
                continue
            tm = re.search(r'<h4>([^<]+)</h4>', card)
            title = ea.text(tm.group(1)) if tm else slug
            if not title or not start:
                continue
            detail_url = BASE + "?go=" + slug
            price_min, price_text = None, None
            try:
                detail_html = ea.fetch(detail_url)
                price_min, price_text = extract_price(detail_html)
            except Exception:
                pass
            records.append({
                "source": "vienna_marathon",
                "source_id": slug,
                "url": detail_url,
                "title": title,
                "start": start,
                "end": None,
                "venue": "Wien",
                "district": None,
                "city": "Wien",
                "address": None,
                "price_min": price_min,
                "price_text": price_text,
                "category": "Bewerbe",
                "description": None,
            })
    ea.emit(records)


if __name__ == "__main__":
    main()
