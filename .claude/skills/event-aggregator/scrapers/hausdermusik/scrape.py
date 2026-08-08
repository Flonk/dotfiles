import re
import time

import ea

SLUG = "hausdermusik"
BASE = "https://www.hdm.at"
PAGE_URL = BASE + "/konzerte/jsf/jet-engine:konzert-loop/pagenum/{}/"
ADDRESS = "Seilerstätte 30, 1010 Wien"
VENUE = "Haus der Musik"
DISTRICT = 1010

BLOCK_RE = re.compile(
    r'jet-listing-dynamic-post-(?P<pid>\d+)"[^>]*data-post-id="(?P=pid)"')
HEAD_RE = re.compile(
    r'elementor-heading-title elementor-size-default">(.*?)</h2>', re.S)
TERM_RE = re.compile(
    r'class="dce-term-item[^"]*">\s*(.*?)\s*</span>', re.S)
LINK_RE = re.compile(r'href="(https://www\.hdm\.at/konzert/[^"]+)"')

EVENTDETAIL_RE = re.compile(
    r'Datum:\s*</br>\s*(?P<datum>[^<]+?)\s*</div>.*?'
    r'Beginn:\s*</br>\s*(?P<beginn>[^<]+?)\s*</div>.*?'
    r'Eintritt:\s*</br>\s*(?P<eintritt>[^<]*?)\s*</div>.*?'
    r'Bühne:\s*</br>\s*(?P<buehne>[^<]+?)\s*</div>', re.S)

DESC_RE = re.compile(
    r'elementor-widget-theme-post-content"[^>]*>\s*<div class="elementor-widget-container">'
    r'(.*?)<div class="elementor-element',
    re.S)


def fetch(url, tries=4):
    for i in range(tries):
        try:
            return ea.fetch(url, timeout=30)
        except Exception:
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))


def parse_date(raw, timeraw):
    m = re.search(r"(\d{2})\.(\d{2})\.(\d{2})", raw)
    if not m:
        return None
    d, mo, y = m.groups()
    date = f"20{y}-{mo}-{d}"
    tm = re.search(r"(\d{1,2}):(\d{2})", timeraw or "")
    if tm:
        return f"{date}T{int(tm.group(1)):02d}:{tm.group(2)}"
    return date


def list_events(html):
    parts = re.split(
        r'(?=<div class="jet-listing-grid__item jet-listing-dynamic-post-\d+")',
        html)
    out = []
    seen = set()
    for p in parts[1:]:
        link = LINK_RE.search(p)
        if not link:
            continue
        url = link.group(1)
        if url in seen:
            continue
        seen.add(url)
        heads = HEAD_RE.findall(p)
        heads = [ea.text(h) for h in heads]
        date_raw = heads[0] if len(heads) > 0 else None
        time_raw = heads[1] if len(heads) > 1 else None
        title = heads[2] if len(heads) > 2 else None
        terms = [ea.text(t) for t in TERM_RE.findall(p)]
        category = terms[0] if terms else None
        out.append({
            "url": url,
            "date_raw": date_raw,
            "time_raw": time_raw,
            "title": title,
            "category": category,
        })
    return out


def detail_info(url):
    html = fetch(url)
    price_min, price_text, venue, start = None, None, VENUE, None
    m = EVENTDETAIL_RE.search(html)
    if m:
        start = parse_date(m.group("datum"), m.group("beginn"))
        eintritt = ea.text(m.group("eintritt"))
        if eintritt:
            price_min, price_text = ea.price(eintritt)
            if price_min is None:
                em = re.search(r"(\d+(?:[.,]\d{1,2})?)\s*Euro", eintritt)
                if em:
                    price_min = float(em.group(1).replace(",", "."))
        buehne = ea.text(m.group("buehne"))
        if buehne:
            venue = f"{VENUE} ({buehne})"
    desc = None
    dm = DESC_RE.search(html)
    if dm:
        desc = ea.text(dm.group(1))
    return start, price_min, price_text, venue, desc


def main():
    cutoff = ea.horizon().isoformat()
    seen_urls = set()
    events = []
    page = 1
    while page <= 30:
        html = fetch(PAGE_URL.format(page))
        page_events = list_events(html)
        if not page_events:
            break
        new = [e for e in page_events if e["url"] not in seen_urls]
        if not new:
            break
        stop = False
        for ev in new:
            seen_urls.add(ev["url"])
            fallback_start = parse_date(ev["date_raw"] or "", ev["time_raw"] or "")
            if fallback_start and fallback_start[:10] > cutoff:
                stop = True
                continue
            events.append(ev)
        if stop:
            break
        page += 1

    records = []
    for ev in events:
        start, price_min, price_text, venue, desc = detail_info(ev["url"])
        if not start:
            start = parse_date(ev["date_raw"] or "", ev["time_raw"] or "")
        if not start:
            continue
        source_id = ev["url"].rstrip("/").rsplit("/", 1)[-1]
        records.append({
            "source": SLUG,
            "source_id": source_id,
            "url": ev["url"],
            "title": ev["title"],
            "start": start,
            "end": None,
            "venue": venue,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": price_min,
            "price_text": price_text,
            "category": ev["category"],
            "description": desc,
        })
    ea.emit(records)


if __name__ == "__main__":
    main()
