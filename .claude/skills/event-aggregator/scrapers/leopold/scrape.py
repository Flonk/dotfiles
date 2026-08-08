import html
import re

import ea

BASE = "https://www.leopoldmuseum.org"
PAGES = [
    "https://www.leopoldmuseum.org/de/ausstellungen",
    "https://www.leopoldmuseum.org/de/ausstellungen/vorschau",
]

ARTICLE_RE = re.compile(
    r'<article class="cfix imgcol exhibition"[^>]*aria-labelledby="article-title(\d+)">'
    r'\s*<a href="([^"]+)">.*?'
    r'<h2 class="title\s*" id="article-title\d+">([^<]*)</h2>\s*'
    r'<p>([^<]*)</p>\s*'
    r'<p>([^<]*)</p></a>\s*</article>',
    re.S,
)


def parse_de_date(s, year=None):
    s = s.strip().rstrip(".")
    parts = [p for p in s.split(".") if p]
    if len(parts) == 3:
        d, m, y = parts
        return f"{int(y):04d}-{int(m):02d}-{int(d):02d}"
    if len(parts) == 2 and year:
        d, m = parts
        return f"{int(year):04d}-{int(m):02d}-{int(d):02d}"
    return None


def parse_range(raw):
    s = html.unescape(raw).strip()
    if s.lower().startswith("seit"):
        start = parse_de_date(s[4:].strip())
        return start, None, True
    if "–" not in s:
        return None, None, False
    start_s, end_s = s.split("–", 1)
    end = parse_de_date(end_s)
    year = end[:4] if end else None
    start = parse_de_date(start_s, year=year)
    return start, end, False


def main():
    seen = set()
    recs = []
    for page_url in PAGES:
        page = ea.fetch(page_url)
        for m in ARTICLE_RE.finditer(page):
            source_id, href, title, subtitle, daterange = m.groups()
            if source_id in seen:
                continue
            seen.add(source_id)

            title = html.unescape(title).strip()
            subtitle = html.unescape(subtitle).strip() or None
            if not title:
                continue

            start, end, permanent = parse_range(daterange)
            if not start:
                continue

            url = href if href.startswith("http") else BASE + href

            extra = {}
            if permanent:
                extra["permanent"] = True

            recs.append({
                "source": "leopold",
                "source_id": source_id,
                "url": url,
                "title": title,
                "start": start,
                "end": end,
                "venue": "Leopold Museum",
                "district": 1070,
                "city": "Wien",
                "address": "Museumsplatz 1, 1070 Wien",
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": subtitle,
                "status": "scheduled",
                "extra": extra or None,
            })

    ea.emit(recs)


if __name__ == "__main__":
    main()
