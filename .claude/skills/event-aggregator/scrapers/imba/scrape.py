import html
import re
import sys
import time
import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

import ea

BASE = "https://www.imba.oeaw.ac.at"
LIST_URL = BASE + "/seminars-events"


def strip_prefix(href):
    return href[len("/imba"):] if href.startswith("/imba") else href

CUR_RE = re.compile(r'class="current"><a[^>]*href="([^"]+)"')
NEXT_RE = re.compile(r'class="next"><a rel="nofollow" href="([^"]+)"')
MY_RE = re.compile(r'month%5D=(\d+).*?year%5D=(\d+)')
ITEM_RE = re.compile(
    r'data-eventid="(\d+)".*?href="([^"]+)".*?<h3 class="event-title">\s*'
    r'([^<]+?)\s*</h3>', re.S)
FIELD_RE = re.compile(
    r'(Date|Time|Speaker|Location|Type|Institute|Host):\s*(.*?)'
    r'(?=,\s*(?:Date|Time|Speaker|Location|Type|Institute|Host):|\s*</p>|$)',
    re.S)


def fetch_retry(url, tries=10):
    last = None
    for i in range(tries):
        try:
            return ea.fetch(url)
        except Exception as e:
            last = e
            time.sleep(min(2 * (i + 1), 15))
    raise last


def month_items(page):
    i = page.find('events-mini-list')
    j = page.find('</ul>', i) if i >= 0 else -1
    chunk = page[i:j] if i >= 0 and j >= 0 else ""
    out = []
    for it in chunk.split('<li><div\n        class="news-mini-cal-item"')[1:]:
        m = ITEM_RE.search(it)
        if m:
            out.append((m.group(1), m.group(2), ea.text(m.group(3))))
    return out


def crawl_ids(cutoff):
    found = {}
    page = fetch_retry(LIST_URL)
    for _ in range(9):
        items = month_items(page)
        for eid, href, title in items:
            found.setdefault(eid, (href, title))
        n = NEXT_RE.search(page)
        if not n:
            break
        m = MY_RE.search(html.unescape(n.group(1)))
        if m and datetime.date(int(m.group(2)), int(m.group(1)), 1) > cutoff:
            break
        next_url = BASE + strip_prefix(html.unescape(n.group(1)))
        try:
            page = fetch_retry(next_url)
        except Exception as e:
            sys.stderr.write(f"month crawl stopped: {e}\n")
            break
    return found


def parse_detail(eid, href, title):
    url = BASE + strip_prefix(href)
    page = fetch_retry(url)
    bi = page.find('news-bodytext')
    body = page[bi:bi + 1500] if bi >= 0 else ""
    fields = {k: ea.text(v) for k, v in FIELD_RE.findall(body)}
    date = fields.get("Date")
    tm = fields.get("Time")
    if not date:
        return None
    start = date
    if tm:
        m = re.match(r'(\d{1,2}):(\d{2})', tm)
        if m:
            start = f"{date}T{int(m.group(1)):02d}:{m.group(2)}"
    ht = page.find('<h1 class="news-title">')
    if ht >= 0:
        he = page.find('</h1>', ht)
        real_title = ea.text(page[ht + len('<h1 class="news-title">'):he])
        if real_title:
            title = real_title
    speaker = fields.get("Speaker")
    if speaker:
        speaker = ea.text(speaker.replace("<br>", "; "))
    venue = fields.get("Location") or None
    category = fields.get("Type") or None
    institute = fields.get("Institute") or None
    hostval = fields.get("Host")
    if hostval in (None, "None", ""):
        hostval = None
    extra = {}
    if speaker:
        extra["speaker"] = speaker
    if institute:
        extra["institute"] = institute
    if hostval:
        extra["host"] = hostval
    return {
        "source": "imba",
        "source_id": eid,
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
    }


def main():
    cutoff = ea.horizon()
    today = datetime.date.today()
    found = crawl_ids(cutoff)

    out = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(parse_detail, eid, href, title): eid
                for eid, (href, title) in found.items()}
        for fut in as_completed(futs):
            try:
                rec = fut.result()
            except Exception as e:
                sys.stderr.write(f"detail failed {futs[fut]}: {e}\n")
                continue
            if not rec:
                continue
            start_date = rec["start"][:10]
            try:
                d = datetime.date.fromisoformat(start_date)
            except ValueError:
                continue
            if d < today or d > cutoff:
                continue
            out.append(rec)

    out.sort(key=lambda r: r["start"])
    ea.emit(out)


if __name__ == "__main__":
    main()
