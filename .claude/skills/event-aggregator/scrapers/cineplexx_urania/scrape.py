import datetime
import re
import sys

import ea

URL = "https://ceenema.eu/spielplan"
VENUE = "Urania Kino"
ADDRESS = "Uraniastraße 1, 1010 Wien"
DISTRICT = 1010

DAY_RE = re.compile(r'id="elem-([^"]*)"')
CARD_RE = re.compile(
    r'<a href="(https://ceenema\.eu/[^"]+)" class="click-link"></a>.*?'
    r'<h6 class="tytuly-24 text-white2">\s*(.*?)\s*</h6>.*?'
    r'<span class="button-text text-white2">\s*(.*?)\s*</span>\s*'
    r'<p class="pt_35 text-white2 text_md">\s*(.*?)\s*</p>.*?'
    r'<div class="select_buttons menu-card-inner-bottom">(.*?)</div>',
    re.S,
)
TIME_RE = re.compile(r'>\s*([0-9]{1,2}:[0-9]{2})\s*<')
DM_RE = re.compile(r'(\d{2})\.(\d{2})$')


def parse_days(html):
    parts = re.split(r'id="elem-([^"]*)"', html)[1:]
    return list(zip(parts[0::2], parts[1::2]))


def resolve_date(label, today):
    m = DM_RE.search(label.strip())
    if not m:
        return None
    day, month = int(m.group(1)), int(m.group(2))
    year = today.year
    d = datetime.date(year, month, day)
    if d < today - datetime.timedelta(days=2):
        d = datetime.date(year + 1, month, day)
    return d


def build(url, title, meta, desc, day):
    title = ea.text(title)
    if not title:
        return None
    meta_t = ea.text(meta)
    desc_t = ea.text(desc)
    parts = [p for p in (meta_t, desc_t) if p]
    description = " — ".join(parts) if parts else None
    slug = url.rstrip("/").rsplit("/", 1)[-1]
    return {
        "url": url,
        "title": title,
        "slug": slug,
        "description": description,
        "day": day,
    }


def main():
    html = ea.fetch(URL, cache="page.html")
    today = datetime.date.today()
    cutoff = ea.horizon()
    records = []
    for label, block in parse_days(html):
        day = resolve_date(label, today)
        if day is None or day > cutoff:
            continue
        for m in CARD_RE.finditer(block):
            url, title, meta, desc, times_block = m.groups()
            base = build(url, title, meta, desc, day)
            if not base:
                continue
            times = TIME_RE.findall(times_block)
            for t in times:
                start = f"{day.isoformat()}T{t}"
                records.append({
                    "source": "cineplexx_urania",
                    "source_id": f"{base['slug']}-{day.isoformat()}-{t}",
                    "url": base["url"],
                    "title": base["title"],
                    "start": start,
                    "end": None,
                    "venue": VENUE,
                    "district": DISTRICT,
                    "city": "Wien",
                    "address": ADDRESS,
                    "price_min": None,
                    "price_text": None,
                    "category": None,
                    "description": base["description"],
                    "status": "scheduled",
                })
    ea.emit(records)


if __name__ == "__main__":
    main()
