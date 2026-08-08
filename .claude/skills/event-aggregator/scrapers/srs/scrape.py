import http.cookiejar
import re
import sys
import urllib.parse
import urllib.request
from datetime import date

import ea

BASE = "https://www.srs.at"

PAGES = [
    "vorfuehrung",
    "morgenarbeit-mit-musik",
    "gefuehrter-rundgang",
    "gefuehrter-rundgang-en",
    "architekturfuehrung",
    "architectural-tour",
    "kinderfuehrung",
    "legende-lipizzaner",
    "legende-lipizzaner-en",
    "briefe-ans-christkind",
]

VENUE = "Spanische Hofreitschule"
ADDRESS = "Michaelerplatz 1, 1010 Wien"
DISTRICT = 1010

MON = {m: i + 1 for i, m in enumerate(
    "Jänner Februar März April Mai Juni Juli August September Oktober "
    "November Dezember".split())}
MON["Jänner"] = 1

BLOCK_RE = re.compile(
    r'event-details-ticket-item-date me-3">(\d+)\.</span>(.*?)event-details-ticket-item-footer',
    re.S)
MONTH_RE = re.compile(r'<strong>([^<]+)</strong>')
TOPTIME_RE = re.compile(r'</strong><br>\s*[^<]*?(?:<br>\s*(\d{1,2}:\d{2})\s*Uhr)?\s*</div>', re.S)
ROW_RE = re.compile(
    r'jetticket">([^<]*)</td>.*?(?:€\s*([\d.,]+))?\s*</td>\s*</tr>', re.S)
EVENTID_RE = re.compile(r'[?&](?:event|eventId)=(\d+)')
TITLE_RE = re.compile(r'<h1>\s*([^<\n]+?)\s*(?:<span|</h1>)', re.S)
CATEGORY_RE = re.compile(r'badge badge-event">\s*([^<]+?)\s*</span>')


def csrf_session():
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    return opener


def fetch_range(opener, url, from_d, to_d):
    req = urllib.request.Request(url, headers={"User-Agent": ea.UA})
    html = opener.open(req, timeout=60).read().decode("utf-8", "replace")
    m = re.search(r'CRAFT_CSRF_TOKEN" value="([^"]+)"', html)
    if not m:
        return html
    token = m.group(1)
    data = urllib.parse.urlencode({
        "CRAFT_CSRF_TOKEN": token,
        "action": "srsfilter/filter/set",
        "fromDate": from_d.strftime("%d.%m.%Y"),
        "toDate": to_d.strftime("%d.%m.%Y"),
    }).encode()
    req2 = urllib.request.Request(url, data=data, headers={"User-Agent": ea.UA})
    return opener.open(req2, timeout=60).read().decode("utf-8", "replace")


def price_of(rows):
    vals = []
    for _label, p in rows:
        if p:
            vals.append(float(p.replace(".", "").replace(",", ".")))
    return min(vals) if vals else None


def parse_page(slug, html):
    title_m = TITLE_RE.search(html)
    title = ea.text(title_m.group(1)) if title_m else slug
    cat_m = CATEGORY_RE.search(html)
    category = cat_m.group(1).strip() if cat_m else None

    url = f"{BASE}/de/tickets/{slug}"
    recs = []
    year = date.today().year
    prev_month = None
    for m in BLOCK_RE.finditer(html):
        day = int(m.group(1))
        block = m.group(2)
        mon_m = MONTH_RE.search(block)
        if not mon_m:
            continue
        month_name = mon_m.group(1).strip()
        month = MON.get(month_name)
        if not month:
            continue
        if prev_month is not None and month < prev_month:
            year += 1
        prev_month = month

        top_m = TOPTIME_RE.search(block)
        top_time = top_m.group(1) if top_m else None

        eid_m = EVENTID_RE.search(block)
        event_id = eid_m.group(1) if eid_m else None

        rows = ROW_RE.findall(block)
        if top_time:
            price_min = price_of(rows)
            start = f"{year:04d}-{month:02d}-{day:02d}T{top_time}"
            source_id = f"{slug}-{event_id or start}"
            recs.append(build(slug, source_id, url, title, start, category, price_min))
        else:
            by_time = {}
            for label, p in rows:
                tm = re.match(r'(\d{1,2}:\d{2})', label.strip())
                if not tm:
                    continue
                t = tm.group(1)
                if p:
                    v = float(p.replace(".", "").replace(",", "."))
                    by_time.setdefault(t, []).append(v)
                else:
                    by_time.setdefault(t, [])
            for t, vals in sorted(by_time.items()):
                start = f"{year:04d}-{month:02d}-{day:02d}T{t}"
                price_min = min(vals) if vals else None
                source_id = f"{slug}-{event_id or ''}-{start}"
                recs.append(build(slug, source_id, url, title, start, category, price_min))
    return recs


def build(slug, source_id, url, title, start, category, price_min):
    price_text = f"ab € {price_min:.2f}".replace(".", ",") if price_min is not None else None
    return {
        "source": "srs",
        "source_id": source_id,
        "url": url,
        "title": title,
        "start": start,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": price_min,
        "price_text": price_text,
        "category": category,
    }


def main():
    end = ea.horizon()
    start = date.today()
    all_recs = []
    for slug in PAGES:
        opener = csrf_session()
        url = f"{BASE}/de/tickets/{slug}"
        try:
            html = fetch_range(opener, url, start, end)
        except Exception as e:
            sys.stderr.write(f"skip {slug}: {e}\n")
            continue
        recs = parse_page(slug, html)
        all_recs.extend(recs)

    ea.emit(all_recs)


if __name__ == "__main__":
    main()
