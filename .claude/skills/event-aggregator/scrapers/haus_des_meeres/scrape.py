import datetime
import html
import re

import ea

URL = "https://www.haus-des-meeres.at/events-kultur/veranstaltungskalender"
VENUE = "Lighthouse10, Haus des Meeres"
ADDRESS = "Fritz-Grünbaum-Platz 1, 1060 Wien"
DISTRICT = 1060

CARD_RE = re.compile(r'<div class="col-lg-4 pb-40">(.*?)</div>\s*</div>', re.S)
LINK_RE = re.compile(r'<a href="([^"]+)"')
TEXT_RE = re.compile(r"<p><strong>(.*?)</strong></p>", re.S)
DATE_TITLE_RE = re.compile(
    r"^\s*(\d{2})\.(\d{2})\.\s*(.+)$", re.S)
CATEGORY_TITLE_RE = re.compile(r"^([^:]+):\s*(.+)$")


def upcoming_block(page):
    try:
        i1 = page.index("Wissenschaft")
        i2 = page.index("Vergangene Veranstaltungen")
    except ValueError:
        return page
    return page[i1:i2]


def parse_card(card, year_state):
    m = TEXT_RE.search(card)
    if not m:
        return None
    raw = html.unescape(re.sub(r"\s+", " ", m.group(1))).strip()
    dm = DATE_TITLE_RE.match(raw)
    if not dm:
        return None
    day, month, rest = int(dm.group(1)), int(dm.group(2)), dm.group(3).strip()

    if month < year_state["last_month"]:
        year_state["year"] += 1
    year_state["last_month"] = month
    year = year_state["year"]

    cat_m = CATEGORY_TITLE_RE.match(rest)
    if cat_m:
        category, title = cat_m.group(1).strip(), cat_m.group(2).strip()
    else:
        category, title = None, rest

    lm = LINK_RE.search(card)
    link = html.unescape(lm.group(1)) if lm else None

    start = f"{year:04d}-{month:02d}-{day:02d}"
    return {
        "source": "haus_des_meeres",
        "source_id": link or f"{start}-{title}",
        "url": link or URL,
        "title": title,
        "start": start,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": category,
        "description": None,
        "status": "scheduled",
    }


def main():
    page = ea.fetch(URL)
    block = upcoming_block(page)
    cards = CARD_RE.findall(block)

    today = datetime.date.today().isoformat()
    cutoff = ea.horizon().isoformat()
    year_state = {"year": datetime.date.today().year, "last_month": 0}

    records = []
    for card in cards:
        rec = parse_card(card, year_state)
        if not rec:
            continue
        if rec["start"] < today or rec["start"] > cutoff:
            continue
        records.append(rec)

    ea.emit(records)


if __name__ == "__main__":
    main()
