import datetime
import json
import os
import re
import sys
import urllib.parse
import urllib.request
import zoneinfo

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

SLUG = "volkstheater"
AJAX_URL = "https://www.volkstheater.at/101/wp-admin/admin-ajax.php"
TZ = zoneinfo.ZoneInfo("Europe/Vienna")

ARTICLE_RE = re.compile(r'<article\b[^>]*>.*?</article>', re.S)
ID_RE = re.compile(r'id="event-(\d+)"')
TIME_RE = re.compile(r'data-time="(\d+)"')
TITLE_RE = re.compile(r'<h3[^>]*><a href="([^"]+)"[^>]*>([^<]+)</a>')
VENUE_RE = re.compile(r'class="spielstaette"[^>]*data-name="([^"]*)"')
CATEGORY_RE = re.compile(r'class="event-type">([^<]*)</div>')
UNTERTITEL_RE = re.compile(r'class="untertitel">([^<]*)</div>')
ZUSATZ_RE = re.compile(r'class="zusatz">([^<]*)</div>')
TICKET_COL_RE = re.compile(r'class="ticket-col">(.*?)</div>\s*<div class="right-col"', re.S)
PRICE_INFO_RE = re.compile(r'class="price-info">([^<]*)</div>')

VENUE_DISTRICT_KEYWORDS = {
    "Volkstheater": 1070,
    "Rote Bar": 1070,
    "Dunkelkammer": 1070,
    "Weißer Salon": 1070,
}


def venue_district(venue):
    if not venue:
        return None
    m = re.search(r"(\d{1,2})\.\s*Bez", venue)
    if m:
        n = int(m.group(1))
        if 1 <= n <= 23:
            return 1000 + n * 10
    for k, v in VENUE_DISTRICT_KEYWORDS.items():
        if k in venue:
            return v
    return None


def parse_articles(html_fragment):
    out = []
    for block in ARTICLE_RE.findall(html_fragment):
        idm = ID_RE.search(block)
        tm = TIME_RE.search(block)
        tim = TITLE_RE.search(block)
        if not (idm and tm and tim):
            continue
        data_id = idm.group(1)
        ts = int(tm.group(1))
        start_dt = datetime.datetime.fromtimestamp(ts, TZ)
        start = start_dt.strftime("%Y-%m-%dT%H:%M")
        url = tim.group(1)
        title = ea.text(tim.group(2))
        if not title:
            continue
        vm = VENUE_RE.search(block)
        venue = ea.text(vm.group(1)) if vm else None
        cm = CATEGORY_RE.search(block)
        category = ea.text(cm.group(1)) if cm else None
        um = UNTERTITEL_RE.search(block)
        untertitel = ea.text(um.group(1)) if um else None
        zm = ZUSATZ_RE.search(block)
        zusatz = ea.text(zm.group(1)) if zm else None
        desc_parts = [p for p in (untertitel, zusatz) if p]
        description = " — ".join(desc_parts) if desc_parts else None
        pm = PRICE_INFO_RE.search(block)
        price_text = ea.text(pm.group(1)) if pm else None
        tcm = TICKET_COL_RE.search(block)
        ticket_text = ea.text(tcm.group(1)) if tcm else None
        if price_text:
            price_min, _ = ea.price(price_text)
        elif ticket_text and re.search(r"frei|gratis|kostenlos", ticket_text, re.I):
            price_min, price_text = 0.0, ticket_text
        else:
            price_min = None
        out.append({
            "source": SLUG,
            "source_id": f"event-{data_id}",
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": venue_district(venue),
            "city": "Wien",
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
            "description": description,
            "extra": {},
        })
    return out


def ajax_call(start_ts, end_ts):
    data = urllib.parse.urlencode({
        "action": "ajax_load_events",
        "start_date": start_ts,
        "end_date": end_ts,
        "load_future_events": "true",
        "jump_date": "",
    }).encode()
    req = urllib.request.Request(AJAX_URL, data=data, headers={
        "User-Agent": ea.UA,
        "Accept-Language": "de-AT,de;q=0.9,en;q=0.8",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def main():
    cutoff = ea.horizon()
    today = datetime.datetime.now(TZ).replace(hour=0, minute=0, second=0, microsecond=0)
    start_ts = int(today.timestamp())
    end_ts = int((today + datetime.timedelta(days=30)).timestamp())

    records = {}
    for _ in range(30):
        d = ajax_call(start_ts, end_ts)
        for r in parse_articles(d.get("events", "")):
            records[r["source_id"]] = r
        has_future = d.get("has_future")
        new_end = d.get("end_date")
        end_dt = datetime.datetime.fromtimestamp(int(new_end), TZ) if new_end else None
        if not has_future:
            break
        if end_dt and end_dt.date() > cutoff:
            break
        end_ts = new_end

    ea.emit(records.values())


if __name__ == "__main__":
    main()
