import datetime
import html
import re

import ea

SLUG = "nhm_ausstellung"
BASE = "https://www.nhm.at"
LIST_URL = "https://www.nhm.at/ausstellung/sonderausstellungen"
VENUE = "Naturhistorisches Museum Wien"
DISTRICT = 1010
ADDRESS = "Burgring 7, 1010 Wien"
NARRENTURM_VENUE = "Narrenturm"
NARRENTURM_DISTRICT = 1090
NARRENTURM_ADDRESS = "Spitalgasse 2, 1090 Wien"

ITEM_RE = re.compile(
    r'<div class="ausstellung(?: ausstellung--liste)?">\s*'
    r'<div class="ausstellung__image[^"]*">.*?<a href="([^"]+)">.*?</div>\s*'
    r'<h3[^>]*>\s*<a href="[^"]+">\s*([^<]*?)\s*</a>\s*</h3>\s*'
    r'<h4[^>]*>\s*([^<]*?)\s*</h4>\s*'
    r'<div class="ausstellung__date[^"]*">\s*([^<]*?)\s*</div>\s*'
    r'<div class="ausstellung__info[^"]*">\s*(.*?)\s*</div>',
    re.S)


def parse_date_field(raw, today):
    s = html.unescape(raw).strip()
    low = s.lower()
    if low.startswith("bis "):
        end = ea.de_date(s[4:].strip())
        return today, end, False
    if low.startswith("ab "):
        start = ea.de_date(s[3:].strip())
        return start, None, True
    if low.startswith("seit "):
        start = ea.de_date(s[5:].strip())
        return start, None, True
    if "–" in s or "-" in s:
        parts = re.split(r"\s*–\s*|\s+-\s+", s, maxsplit=1)
        if len(parts) == 2:
            end = ea.de_date(parts[1].strip())
            start = ea.de_date(parts[0].strip())
            return start, end, False
    return None, None, False


def main():
    page = ea.fetch(LIST_URL, cache="page.html")
    today = datetime.date.today().isoformat()

    recs = []
    seen = set()
    for m in ITEM_RE.finditer(page):
        href, title, subtitle, date_raw, info = m.groups()
        title = html.unescape(title).strip()
        subtitle = ea.text(subtitle) or None
        info_txt = ea.text(info) or None
        if not title or not href:
            continue

        start, end, permanent = parse_date_field(date_raw, today)
        if not start:
            continue

        url = href if href.startswith("http") else BASE + href
        source_id = href.rstrip("/").rsplit("/", 1)[-1]
        if source_id in seen:
            continue
        seen.add(source_id)

        description = " – ".join(x for x in (subtitle, info_txt) if x) or None

        extra = {}
        if permanent:
            extra["permanent"] = True

        is_narrenturm = "narrenturm" in (description or "").lower()
        venue = NARRENTURM_VENUE if is_narrenturm else VENUE
        district = NARRENTURM_DISTRICT if is_narrenturm else DISTRICT
        address = NARRENTURM_ADDRESS if is_narrenturm else ADDRESS

        recs.append({
            "source": SLUG,
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": district,
            "city": "Wien",
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": "Sonderausstellung",
            "description": description,
            "status": "scheduled",
            "extra": extra or None,
        })

    ea.emit(recs)


if __name__ == "__main__":
    main()
