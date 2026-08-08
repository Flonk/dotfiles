import re

import ea

SLUG = "dommuseum"
BASE = "https://www.dommuseum.at"

CAL_ITEM = re.compile(
    r'<div class="category_list_item[^"]*" aid="(?P<aid>\d+)">.*?'
    r'<a href="(?P<url>[^"]+)">\s*<img[^>]*/>\s*</a>.*?'
    r'<div class="list_item_date regular">\s*(?P<date>.*?)</div>\s*'
    r'<div class="list_item_title semibold">(?P<title>.*?)</div>.*?'
    r'<div class="list_item_category_place semibold">\s*(?P<catplace>.*?)</div>\s*'
    r'<div class="list_item_teaser regular">\s*(?P<teaser>.*?)</div>',
    re.S)

SLIDER_ITEM = re.compile(
    r'<div class="homeSliderText[^"]*">\s*([^<]+?)\s*'
    r'<a class="sliderMoreButton"\s+href="([^"]+)"[^>]*>.*?<h2>\s*(.*?)\s*</h2>',
    re.S)


def parse_cal_date(raw):
    m = re.search(r"(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s*(\d{4})", raw)
    if not m:
        return None, None
    day, monname, year = m.groups()
    mon = ea.MON.get(monname.capitalize()) or ea.MON.get(monname[:3].capitalize())
    if not mon:
        return None, None
    date = f"{int(year):04d}-{mon:02d}-{int(day):02d}"
    times = re.findall(r"(\d{1,2}):(\d{2})", raw[m.end():])
    start = f"{date}T{int(times[0][0]):02d}:{times[0][1]}" if times else date
    end = f"{date}T{int(times[1][0]):02d}:{times[1][1]}" if len(times) > 1 else None
    return start, end


def calendar_events(html):
    out = []
    for m in CAL_ITEM.finditer(html):
        start, end = parse_cal_date(ea.text(m.group("date")) or "")
        if not start:
            continue
        title = ea.text(m.group("title"))
        catplace = ea.text(m.group("catplace")) or ""
        parts = [p.strip() for p in catplace.split(",")]
        category = parts[0] if parts else None
        venue = parts[1] if len(parts) > 1 else "Dom Museum Wien"
        teaser = ea.text(m.group("teaser"))
        url = m.group("url")
        out.append({
            "source": SLUG,
            "source_id": m.group("aid"),
            "url": url,
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": 1010,
            "city": "Wien",
            "address": "Stephansplatz 6, 1010 Wien",
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": teaser,
        })
    return out


def exhibition_event(home_html, ticket_price_min, ticket_price_text):
    for label, url, title in SLIDER_ITEM.findall(home_html):
        if not label.strip().startswith("Ausstellung"):
            continue
        detail = ea.fetch(url)
        sub = re.search(r'class="start_subtitle">(.*?)</div>', detail, re.S)
        if not sub:
            continue
        raw_range = ea.text(sub.group(1)) or ""
        dates = re.findall(r"(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s*(\d{4})", raw_range)
        if len(dates) < 2:
            continue
        (d1, mo1, y1), (d2, mo2, y2) = dates[0], dates[1]
        mon1 = ea.MON.get(mo1.capitalize())
        mon2 = ea.MON.get(mo2.capitalize())
        if not (mon1 and mon2):
            continue
        start = f"{int(y1):04d}-{mon1:02d}-{int(d1):02d}"
        end = f"{int(y2):04d}-{mon2:02d}-{int(d2):02d}"
        desc_m = re.search(r'class="module module_text[^"]*"[^>]*><p>(.*?)</p>', detail, re.S)
        description = ea.text(desc_m.group(1)) if desc_m else None
        return [{
            "source": SLUG,
            "source_id": url.rsplit("/", 1)[-1],
            "url": url,
            "title": ea.text(title),
            "start": start,
            "end": end,
            "venue": "Dom Museum Wien",
            "district": 1010,
            "city": "Wien",
            "address": "Stephansplatz 6, 1010 Wien",
            "price_min": ticket_price_min,
            "price_text": ticket_price_text,
            "category": "Ausstellung",
            "description": description,
        }]
    return []


def ticket_price(home_html):
    url = BASE + "/tickets"
    html = ea.fetch(url)
    m = re.search(r"Regulär\s*€\s*(\d+(?:[.,]\d+)?)", ea.text(html) or "")
    if m:
        return float(m.group(1).replace(",", ".")), f"Regulär € {m.group(1)}"
    return None, None


def main():
    home = ea.fetch(BASE + "/")
    cal = ea.fetch(BASE + "/category/kalender")

    records = calendar_events(cal)

    price_min, price_text = ticket_price(home)
    records += exhibition_event(home, price_min, price_text)

    ea.emit(records)


if __name__ == "__main__":
    main()
