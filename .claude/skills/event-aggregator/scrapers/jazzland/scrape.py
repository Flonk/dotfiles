import datetime
import re
import sys

import ea

MENU_URL = "https://www.jazzland.at/jl_menu.php"
BASE = "https://www.jazzland.at/prog/"
VENUE = "Jazzland"
ADDRESS = "Franz-Josefs-Kai 29, 1010 Wien"
DISTRICT = 1010
PRICE_TEXT = "ca. EUR 15,- bis EUR 22,- (unverbindlicher Richtpreis, variiert je Band)"

DATE_RE = re.compile(r"(\d{1,2})\s*\.\s*(\d{1,2})\s*\.")
ROW_DATE_RE = re.compile(r'<td title="(\d{4})"[^>]*>(.*?)</td>', re.S)
ANCHOR_RE = re.compile(r'href="#(D[^"]+)"')
CAT_RE = re.compile(r'<td title="([^"]*)"[^>]*>\s*[A-Z](?:<br\s*/?>\s*[A-Z])*\s*</td>')


def current_program_url(menu_page):
    m = re.search(r'href="prog/(jlp\d{4}\.htm)"\s+title="aktuelles Programm"', menu_page)
    if not m:
        raise RuntimeError("could not find current program link in jl_menu.php")
    return BASE + m.group(1)


def parse_rows(page):
    m = re.search(r'<table[^>]*class="uetab"[^>]*>(.*?)</table>', page, re.S)
    if not m:
        return []
    rows = re.findall(r"<tr>(.*?)</tr>", m.group(1), re.S)
    out = []
    for r in rows:
        dm = ROW_DATE_RE.search(r)
        am = ANCHOR_RE.search(r)
        if not dm or not am:
            continue
        year = dm.group(1)
        date_html = dm.group(2)
        tds = re.findall(r"<td[^>]*>(.*?)</td>", r, re.S)
        if len(tds) < 4:
            continue
        title_html, desc_html, cat_html = tds[1], tds[2], tds[3]
        catm = CAT_RE.search(r)
        category = ea.text(catm.group(1)) if catm else None
        title = ea.text(title_html)
        desc = ea.text(desc_html)
        if not title:
            continue
        dates = []
        for part in re.split(r"<br\s*/?>", date_html):
            dmm = DATE_RE.search(part)
            if dmm:
                day, month = int(dmm.group(1)), int(dmm.group(2))
                try:
                    dates.append(datetime.date(int(year), month, day))
                except ValueError:
                    continue
        for d in dates:
            out.append({
                "anchor": am.group(1),
                "date": d,
                "title": title,
                "description": desc,
                "category": category,
            })
    return out


def build(row, page_url):
    start = row["date"].isoformat()
    return {
        "source": "jazzland",
        "source_id": f"{row['anchor']}-{start}",
        "url": f"{page_url}#{row['anchor']}",
        "title": row["title"],
        "start": start,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": PRICE_TEXT,
        "category": row["category"],
        "description": row["description"],
        "status": "scheduled",
    }


def main():
    menu_page = ea.fetch(MENU_URL)
    page_url = current_program_url(menu_page)
    page = ea.fetch(page_url)
    rows = parse_rows(page)
    today = datetime.date.today()
    records = []
    for row in rows:
        if row["date"] < today:
            continue
        records.append(build(row, page_url))
    ea.emit(records)


if __name__ == "__main__":
    main()
