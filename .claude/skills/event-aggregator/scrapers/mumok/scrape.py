import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://www.mumok.at"
PAGES = [BASE + "/ausstellungen/aktuell", BASE + "/ausstellungen/vorschau"]

MONTHS = {
    "januar": 1, "februar": 2, "märz": 3, "april": 4, "mai": 5, "juni": 6,
    "juli": 7, "august": 8, "september": 9, "oktober": 10,
    "november": 11, "dezember": 12,
}


def parse_de_date(s, fallback_year=None):
    s = s.strip()
    m = re.match(r"(\d{1,2})\.\s*([A-Za-zäöüÄÖÜ]+)?\s*(\d{4})?", s)
    if not m:
        return None
    day = int(m.group(1))
    mon_name = m.group(2)
    year = m.group(3)
    month = MONTHS.get(mon_name.lower()) if mon_name else None
    if month is None or year is None:
        if fallback_year:
            month = month or fallback_year[0]
            year = year or fallback_year[1]
    if month is None or year is None:
        return None
    return f"{int(year):04d}-{int(month):02d}-{int(day):02d}"


def parse_block(block):
    m = re.search(
        r'<div class="exhib-overline">(.*?)</div>\s*<div class="title">(.*?)</div>\s*'
        r'<div class="cta-button">\s*<a[^>]+href="([^"]+)"',
        block, re.S)
    if not m:
        return None
    overline_raw, title_raw, href = m.groups()
    overline = ea.text(overline_raw) or ""
    title = ea.text(title_raw) or ""
    if not title or not overline:
        return None
    parts = re.split(r"\bbis\b", overline, maxsplit=1)
    if len(parts) != 2:
        return None
    start_raw, end_raw = parts[0].strip(), parts[1].strip()
    end_m = re.match(r"(\d{1,2})\.\s*([A-Za-zäöüÄÖÜ]+)?\s*(\d{4})", end_raw)
    if not end_m:
        return None
    end_year = end_m.group(3)
    end_month_name = end_m.group(2)
    end_month = MONTHS.get(end_month_name.lower()) if end_month_name else None
    end = parse_de_date(end_raw)
    start = parse_de_date(start_raw, fallback_year=(end_month, end_year))
    if not start or not end:
        return None
    url = href if href.startswith("http") else BASE + href
    return {
        "title": title,
        "start": start,
        "end": end,
        "url": url,
    }


def main():
    seen = {}
    for page_url in PAGES:
        cache = os.path.join(os.path.dirname(__file__), "page_" +
                              page_url.rsplit("/", 1)[-1] + ".html")
        page = ea.fetch(page_url, cache=cache)
        for m in re.finditer(r'teaserbox exhib', page):
            block = page[m.start():m.start() + 3000]
            rec = parse_block(block)
            if not rec:
                continue
            seen[rec["url"]] = rec
        if os.path.exists(cache):
            os.remove(cache)

    out = []
    for url, rec in seen.items():
        slug = url.rstrip("/").rsplit("/", 1)[-1]
        out.append({
            "source": "mumok",
            "source_id": slug,
            "url": url,
            "title": rec["title"],
            "start": rec["start"],
            "end": rec["end"],
            "venue": "mumok",
            "district": 1070,
            "city": "Wien",
            "address": "Museumsplatz 1, 1070 Wien",
            "price_min": None,
            "price_text": None,
            "category": "Ausstellung",
            "description": None,
            "extra": {},
        })
    ea.emit(out)


if __name__ == "__main__":
    main()
