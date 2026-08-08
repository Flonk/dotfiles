import re, sys, json, urllib.request, datetime as dt

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126.0 Safari/537.36"
BASE = "https://www.meinbezirk.at"

MONTHS = {m: i + 1 for i, m in enumerate(
    "Jänner Februar März April Mai Juni Juli August September Oktober November Dezember".split())}

ITEM = re.compile(r'<article class="content-list-item[^"]*"\s+data-eventitem-id="(\d+)"(.*?)</article>', re.S)
HREF = re.compile(r'href="(/event/[^"]*_e\d+)"')
DATE = re.compile(r'fa-calendar-alt"></i>\s*([^<]+?)\s*</li>', re.S)
LIS = re.compile(r'<li>([^<]*?)</li>', re.S)
H3 = re.compile(r'<h3[^>]*content-card-headline[^>]*>.*?<a[^>]*>(.*?)</a>', re.S)


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=45).read().decode("utf-8", "replace")


def parse_date(s):
    # "9. August 2026 um 10:00"  |  "9. August 2026"  | "9. August 2026 bis 12. August 2026"
    s = s.replace("&nbsp;", " ").strip()
    m = re.search(r'(\d{1,2})\.\s*(\w+)\s*(\d{4})(?:\s*um\s*(\d{1,2}):(\d{2}))?', s)
    if not m:
        return None, s
    d, mon, y, hh, mm = m.groups()
    if mon not in MONTHS:
        return None, s
    if hh is None:
        return dt.datetime(int(y), MONTHS[mon], int(d)), s
    return dt.datetime(int(y), MONTHS[mon], int(d), int(hh), int(mm)), s


def scrape(scope="today", max_pages=20):
    seen, out = set(), []
    for page in range(1, max_pages + 1):
        url = f"{BASE}/event/wien/list/{scope}" + (f"/{page}" if page > 1 else "")
        try:
            html = get(url)
        except Exception as e:
            print(f"  ! page {page}: {e}", file=sys.stderr)
            break
        items = ITEM.findall(html)
        if not items:
            break
        new = 0
        for eid, body in items:
            if eid in seen:
                continue
            seen.add(eid)
            new += 1
            href = HREF.search(body)
            title = H3.search(body)
            dtxt = DATE.search(body)
            lis = [x.strip() for x in LIS.findall(body) if x.strip()]
            when, raw = parse_date(dtxt.group(1)) if dtxt else (None, "")
            path = href.group(1) if href else ""
            cat = re.search(r'/c-([a-z-]+)/', path)
            dist = re.search(r'/event/([a-z-]+)/', path)
            out.append({
                "id": eid,
                "title": re.sub(r'\s+', ' ', title.group(1)).strip() if title else "",
                "url": BASE + path,
                "start": when.isoformat() if when else None,
                "when_raw": raw,
                "venue": lis[1] if len(lis) > 1 else "",
                "district": dist.group(1) if dist else "",
                "category": cat.group(1) if cat else "",
            })
        if new == 0:
            break
    return out


if __name__ == "__main__":
    scope = sys.argv[1] if len(sys.argv) > 1 else "today"
    evs = scrape(scope)
    print(json.dumps(evs, ensure_ascii=False, indent=1))
    print(f"\n=== {len(evs)} events for scope={scope}", file=sys.stderr)
