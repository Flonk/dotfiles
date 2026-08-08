import datetime
import re

import ea

LIST_URL = "https://chelsea.co.at/concerts.php"
VENUE = "Chelsea"
ADDRESS = "Lerchenfelder Gürtel, U-Bahnbögen 29-30, 1080 Wien"
DISTRICT = 1080

BLOCK_RE = re.compile(r'<a name="concert_(\d+)"></a>(.*?)(?=<a name="concert_\d+"></a>|</body>)', re.S)
DATE_RE = re.compile(r'<div class="date">\s*(?:[A-Za-zäöü]{2},\s*)?(\d{1,2})\.(\d{1,2})\.(\d{4})?\s*</div>')
BAND_RE = re.compile(r'<div class="band"><span class="highlight">(.*?)</span></div>', re.S)
PRICE_RE = re.compile(r'<div class="price">(.*?)</div>', re.S)
TEXT_RE = re.compile(
    r'<div class="text">(.*?)<table cellpadding="0" cellspacing="0" width="100%" '
    r'style="margin-top:15px;margin-bottom:15px">', re.S)


def parse_date(m, last_date):
    day, month = int(m.group(1)), int(m.group(2))
    year = int(m.group(3)) if m.group(3) else (last_date.year if last_date else datetime.date.today().year)
    try:
        d = datetime.date(year, month, day)
    except ValueError:
        return None
    if not m.group(3) and last_date and d < last_date:
        d = datetime.date(year + 1, month, day)
    return d


def parse_price(raw):
    text = ea.text(raw) or ""
    if re.search(r"\bfrei\b|\bgratis\b|\bfree\b", text, re.I):
        return 0.0, text
    vvk = text.split("/AK")[0]
    m = re.search(r"(\d+)(?:[.,](\d{2}))(?!\d)", vvk)
    if m:
        return float(f"{m.group(1)}.{m.group(2)}"), text
    m = re.search(r"(\d+)", vvk)
    if m:
        return float(m.group(1)), text
    return None, text


def build(eid, block, last_date):
    dm = DATE_RE.search(block)
    if not dm:
        return None, last_date
    d = parse_date(dm, last_date)
    if not d:
        return None, last_date
    bm = BAND_RE.search(block)
    title = ea.text(bm.group(1)) if bm else None
    if not title:
        return None, d
    pm = PRICE_RE.search(block)
    price_min, price_text = parse_price(pm.group(1)) if pm else (None, None)
    tm = TEXT_RE.search(block)
    desc = ea.text(tm.group(1)) if tm else None
    url = f"https://chelsea.co.at/concerts.php#concert_{eid}"
    rec = {
        "source": "chelsea",
        "source_id": eid,
        "url": url,
        "title": title,
        "start": d.isoformat(),
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": price_min,
        "price_text": price_text,
        "category": None,
        "description": desc,
        "status": "scheduled",
    }
    return rec, d


def main():
    page = ea.fetch(LIST_URL)
    cutoff = ea.horizon()
    records = []
    last_date = None
    for m in BLOCK_RE.finditer(page):
        eid, block = m.group(1), m.group(2)
        rec, last_date = build(eid, block, last_date)
        if not rec:
            continue
        if datetime.date.fromisoformat(rec["start"]) > cutoff:
            continue
        records.append(rec)
    ea.emit(records)


if __name__ == "__main__":
    main()
