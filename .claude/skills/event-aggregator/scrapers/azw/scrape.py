import datetime
import re

import ea

URL = "https://www.azw.at/de/programm/"
BASE = "https://www.azw.at"

ITEM_RE = re.compile(r'<li\s+class=event-list_item(.*?)</li>', re.S)
CAT_RE = re.compile(r'data-category=(?:"([^"]*)"|(\S+))')
START_RE = re.compile(r'data-startDate=(\S+)')
END_RE = re.compile(r'data-endDate=(\S+)')
HREF_RE = re.compile(r'<a\s+class="event-card[^"]*"\s+href=(\S+)')
LABEL_RE = re.compile(r'class="event-card_label\s*">\s*([^<]*)<')
TITLE_RE = re.compile(r'class="event-card_title[^"]*">(.*?)</h3>', re.S)
LOC_RE = re.compile(r'Ort:\s*([^<]*)</div>')
TIME_RE = re.compile(r'class=event-card_time>([^<]*)<')
EXCERPT_RE = re.compile(r'class=event-card_excerpt>(.*?)</div>', re.S)

NON_VIENNA = {"afo architekturforum oberösterreich": "Linz"}


def parse_block(block, cutoff):
    cm = CAT_RE.search(block)
    category = ea.text(cm.group(1) or cm.group(2)) if cm else None

    sm = START_RE.search(block)
    em = END_RE.search(block)
    if not sm:
        return None
    start_d = sm.group(1)
    end_d = em.group(1) if em else None
    try:
        start_date = datetime.date.fromisoformat(start_d)
    except ValueError:
        return None
    end_date = None
    if end_d:
        try:
            end_date = datetime.date.fromisoformat(end_d)
        except ValueError:
            end_date = None
    if (end_date or start_date) < datetime.date.today():
        return None
    if start_date > cutoff:
        return None

    hm = HREF_RE.search(block)
    if not hm:
        return None
    href = hm.group(1)
    url = href if href.startswith("http") else BASE + href
    m_id = re.search(r'/de/termin/(.+?)/?$', url)
    source_id = m_id.group(1) if m_id else url

    lm = LABEL_RE.search(block)
    label = ea.text(lm.group(1)) if lm else None

    tm = TITLE_RE.search(block)
    title = ea.text(tm.group(1)) if tm else None
    if not title:
        return None

    locm = LOC_RE.search(block)
    venue = ea.text(locm.group(1)) if locm else None

    excm = EXCERPT_RE.search(block)
    description = ea.text(excm.group(1)) if excm else None

    start = start_d
    if start_date == end_date or not end_d:
        tmm = TIME_RE.search(block)
        if tmm:
            t = re.search(r'(\d{1,2})[:.](\d{2})', tmm.group(1))
            if t:
                start = f"{start_d}T{int(t.group(1)):02d}:{t.group(2)}"

    end = end_d if end_d and end_d != start_d else None

    city = "Wien"
    district = None
    if venue:
        for k, v in NON_VIENNA.items():
            if k in venue:
                city = v
                break
        district = ea.district(venue)

    return {
        "source": "azw",
        "source_id": source_id,
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": district,
        "city": city,
        "address": None,
        "price_min": None,
        "price_text": None,
        "category": label or category,
        "description": description,
        "status": "scheduled",
    }


def main():
    page = ea.fetch(URL)
    cutoff = ea.horizon()
    out = []
    for m in ITEM_RE.finditer(page):
        rec = parse_block(m.group(1), cutoff)
        if rec:
            out.append(rec)
    ea.emit(out)


if __name__ == "__main__":
    main()
