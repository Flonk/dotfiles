import datetime
import re
import sys

sys.path.insert(0, "../../lib")
import ea

BASE = "https://www.sirene.at"
SLUG = "sirene"

MONTHS = ea.MON

DATE_RE = re.compile(
    r"((?:\d{1,2}\.,\s*)*\d{1,2}\.)\s+([A-ZÄÖÜ][a-zäöüß]+)\s+(\d{4})"
    r"(?:,?\s*(?:jeweils\s+um|Beginn\s+jeweils\s+um|Beginn\s+um)?\s*(\d{1,2})[:.](\d{2})\s*Uhr)?"
)
LINK_RE = re.compile(r"<a\s+(?:class='[^']*'\s+)?href='(/projekte/[^']+/)'>([^<]*)</a>")
ADDR_RE = re.compile(
    r"([A-ZÄÖÜ][\wäöüß.\- ]+?theater)\s*,?\s*<br",
)


def project_links(html):
    out = []
    for m in LINK_RE.finditer(html):
        href, txt = m.group(1), m.group(2).strip()
        if href.count("/") != 3:
            continue
        ym = re.match(r"(\d{4})", txt)
        if not ym:
            continue
        out.append((href, txt, int(ym.group(1))))
    return out


def parse_occurrences(html, url, title, today):
    body_m = re.search(r'<div id="content">(.*?)</div><!-- Ende content', html, re.S)
    if not body_m:
        return []
    plain = ea.text(body_m.group(1)) or ""

    venue = None
    addr = None
    district = None
    m = re.search(r"(Jugendstiltheater)\s*,?\s*([^.]*?\d{4}\s*Wien)", plain)
    if m:
        venue = m.group(1)
        addr = f"{m.group(1)}, {m.group(2)}".strip()
        district = ea.district(addr)

    price_min, price_text = None, None
    pm = re.search(r"(?:€|EUR)\s*\d+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?\s*(?:€|EUR)", plain)
    if pm:
        price_min, price_text = ea.price(pm.group(0))
    elif re.search(r"\b(eintritt\s+frei|freier\s+eintritt|gratis|kostenlos)\b", plain, re.I):
        price_min, price_text = 0.0, "frei"

    recs = []
    for dm in DATE_RE.finditer(plain):
        days_raw, mon_name, year, hh, mm = dm.groups()
        mon = MONTHS.get(mon_name) or MONTHS.get(mon_name[:3])
        if not mon:
            continue
        days = re.findall(r"\d{1,2}", days_raw)
        for d in days:
            date = datetime.date(int(year), mon, int(d))
            if date < today:
                continue
            start = f"{date.isoformat()}T{int(hh):02d}:{mm}" if hh else date.isoformat()
            recs.append({
                "source": SLUG,
                "source_id": f"{url}#{date.isoformat()}",
                "url": url,
                "title": title,
                "start": start,
                "end": None,
                "venue": venue,
                "district": district,
                "city": "Wien",
                "address": addr,
                "price_min": price_min,
                "price_text": price_text,
                "category": "Oper",
                "description": None,
            })
    return recs


def main():
    today = datetime.date.today()

    idx_html = ea.fetch(f"{BASE}/projekte/")
    links = project_links(idx_html)

    year = today.year
    candidates = [(h, t) for h, t, y in links if y >= year - 1]

    records = []
    seen = set()
    for href, txt in candidates:
        if href in seen:
            continue
        seen.add(href)
        url = BASE + href
        page = ea.fetch(url)
        h1m = re.search(r"<h1>\s*(.*?)\s*</h1>", page, re.S)
        title = ea.text(h1m.group(1)) if h1m else txt
        records.extend(parse_occurrences(page, url, title, today))

    ea.emit(records)


if __name__ == "__main__":
    main()
