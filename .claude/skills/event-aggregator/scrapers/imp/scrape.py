import re
import sys
import datetime
import ea

BASE = "https://www.imp.ac.at"
LIST_URL = BASE + "/calendar"
API_URL = (BASE + "/index.php?id=222&type=8881&cat=&beginndate=&enddate="
           "&keyword=&offset={offset}")

ITEM_RE = re.compile(
    r'<div class="events__item"[^>]*>(.*?)</div>\s*</div>\s*'
    r'(?=<div class="events__item"|<div class="content__block"|$)', re.S)
DAY_RE = re.compile(r'events__item-day">(\d+)<')
MON_RE = re.compile(r'events__item-month">([A-Za-z]+)<')
YEAR_RE = re.compile(r'events__item-year">(\d+)<')
TIME_RE = re.compile(r'events__item-date">(\d{1,2}:\d{2})<')
LINK_RE = re.compile(r'<a class="events__item-text" href="([^"]+)">\s*(.*?)\s*</a>', re.S)
VENUE_RE = re.compile(r'events__item-title">([^<]*)<')
SPEAKER_RE = re.compile(r'events__item-speaker">\s*<dd>(?:<strong>)?(.*?)(?:</strong>)?</dd>', re.S)
DL_RE = re.compile(r'<dl class="events__dl">(.*?)</dl>', re.S)
DD_RE = re.compile(r'<dd>(.*?)</dd>', re.S)
TAG_RE = re.compile(r'<span class="tag[^"]*">([^<]*)</span>')


def parse_items(chunk, cutoff, seen, out):
    stop = False
    for m in ITEM_RE.finditer(chunk):
        block = m.group(1)
        day, mon, year = DAY_RE.search(block), MON_RE.search(block), YEAR_RE.search(block)
        if not (day and mon and year):
            continue
        month_num = ea.MON.get(mon.group(1)) or ea.MON.get(mon.group(1)[:3])
        if not month_num:
            continue
        date = datetime.date(int(year.group(1)), month_num, int(day.group(1)))
        if date > cutoff:
            stop = True
            continue
        link = LINK_RE.search(block)
        if not link:
            continue
        href, title = link.group(1), ea.text(link.group(2))
        url = href if href.startswith("http") else BASE + href
        m_id = re.search(r'-(\d+)$', href)
        source_id = m_id.group(1) if m_id else url
        if source_id in seen:
            continue
        seen.add(source_id)
        t = TIME_RE.search(block)
        start = f"{date.isoformat()}T{t.group(1)}" if t else date.isoformat()
        venue = None
        v = VENUE_RE.search(block)
        if v:
            venue = ea.text(v.group(1))
        dl = DL_RE.search(block)
        speaker = institute = None
        if dl:
            sp = SPEAKER_RE.search(dl.group(1))
            if sp:
                speaker = ea.text(sp.group(1))
            dds = DD_RE.findall(dl.group(1))
            if dds:
                last = ea.text(dds[-1])
                if last and last != speaker:
                    institute = last
        tags = TAG_RE.findall(block)
        category = ea.text(", ".join(t.strip() for t in tags if t.strip())) if tags else None
        extra = {}
        if speaker:
            extra["speaker"] = speaker
        if institute:
            extra["institute"] = institute
        out.append({
            "source": "imp",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": None,
            "city": "Wien",
            "address": None,
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": None,
            "extra": extra or None,
        })
    return stop


def main():
    cutoff = ea.horizon()
    seen = set()
    out = []
    page = ea.fetch(LIST_URL, cache="page.html")
    stop = parse_items(page, cutoff, seen, out)

    m = re.search(r"data-all='(\d+)'", page)
    total = int(m.group(1)) if m else len(out)
    perpage_m = re.search(r"data-perpage='(\d+)'", page)
    perpage = int(perpage_m.group(1)) if perpage_m else 15

    offset = perpage
    while not stop and offset < total:
        chunk = ea.fetch(API_URL.format(offset=offset))
        if not chunk.strip():
            break
        stop = parse_items(chunk, cutoff, seen, out)
        offset += perpage

    ea.emit(out)


if __name__ == "__main__":
    main()
