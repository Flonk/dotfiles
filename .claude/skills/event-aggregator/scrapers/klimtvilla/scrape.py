import datetime
import html
import re
import sys
import urllib.parse
import urllib.request

import ea

URL = "https://www.klimtvilla.at/veranstaltungen/"
AJAX_URL = "https://www.klimtvilla.at/wp-admin/admin-ajax.php"
VENUE_DISTRICT = {"Klimt Villa Wien": 1130}

SETTINGS_RE = re.compile(r"mecListView\(\s*\{(.*?)\}\s*\);", re.S)
CAT_BLOCK_RE = re.compile(r'<dd class="mec-events-event-categories">(.*?)</dd>', re.S)
CAT_A_RE = re.compile(r"<a[^>]*>(?:<i[^>]*></i>)?\s*([^<]+?)\s*</a>")

STATUS_MAP = {
    "https://schema.org/EventScheduled": "scheduled",
    "https://schema.org/EventCancelled": "cancelled",
    "https://schema.org/EventPostponed": "postponed",
    "https://schema.org/EventMovedOnline": "scheduled",
    "https://schema.org/EventRescheduled": "scheduled",
}


def parse_settings(page):
    m = SETTINGS_RE.search(page)
    if not m:
        return None
    block = m.group(1)

    def gv(name):
        mm = re.search(name + r':\s*"([^"]*)"', block)
        return mm.group(1) if mm else None

    return {
        "atts": gv("atts"),
        "end_date": gv("end_date"),
        "offset": gv("offset"),
        "current_month_divider": gv("current_month_divider"),
    }


def events_from_html(fragment):
    return [d for d in ea.jsonld(fragment) if d.get("@type") == "Event"]


def post(url, body):
    req = urllib.request.Request(
        url, data=body.encode("utf-8"),
        headers={"User-Agent": ea.UA, "Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=30) as r:
        import json
        return json.loads(r.read().decode("utf-8", "replace"))


def load_more(atts, end_date, offset, current_month_divider, horizon):
    events = []
    for _ in range(40):
        body = (f"action=mec_list_load_more&mec_start_date={end_date}"
                f"&mec_offset={offset}&{atts}"
                f"&current_month_divider={current_month_divider}&apply_sf_date=0")
        try:
            resp = post(AJAX_URL, body)
        except Exception as e:
            sys.stderr.write(f"load_more failed: {e}\n")
            break
        if not resp.get("count"):
            break
        events.extend(events_from_html(resp.get("html", "")))
        end_date = resp["end_date"]
        offset = resp["offset"]
        current_month_divider = resp["current_month_divider"]
        if end_date and end_date > (horizon + datetime.timedelta(days=60)).isoformat():
            break
    return events


def fetch_category(url):
    try:
        page = ea.fetch(url)
    except Exception:
        return None
    m = CAT_BLOCK_RE.search(page)
    if not m:
        return None
    cats = [html.unescape(c).strip() for c in CAT_A_RE.findall(m.group(1)) if c.strip()]
    return ", ".join(cats) if cats else None


def to_local(dt_str):
    if not dt_str:
        return None
    if len(dt_str) == 10:
        return dt_str
    m = re.match(r"(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2})", dt_str)
    return f"{m.group(1)}T{m.group(2)}:{m.group(3)}" if m else dt_str[:10]


def build(e):
    start = to_local(e.get("startDate"))
    if not start:
        return None
    end = to_local(e.get("endDate")) or None

    loc = e.get("location") or {}
    venue = loc.get("name")
    address = loc.get("address")
    district = VENUE_DISTRICT.get(venue) or ea.district(address)

    offers = e.get("offers") or {}
    price_min = None
    if offers.get("price") not in (None, ""):
        try:
            price_min = float(str(offers["price"]).replace(",", "."))
        except ValueError:
            price_min = None
    price_text = (f"{offers.get('price')} {offers.get('priceCurrency')}".strip()
                  if offers.get("price") else None)

    url = e.get("url") or offers.get("url")
    if not url:
        return None
    url = html.unescape(url)
    slug = urllib.parse.urlsplit(url).path.rstrip("/").rsplit("/", 1)[-1]
    if not slug:
        return None

    title = html.unescape(e.get("name") or "").strip() or None
    if not title:
        return None

    status = STATUS_MAP.get(e.get("eventStatus"), "scheduled")

    return {
        "source": "klimtvilla",
        "source_id": slug,
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": district,
        "city": "Wien",
        "address": address,
        "price_min": price_min,
        "price_text": price_text,
        "category": fetch_category(url),
        "description": ea.text(e.get("description")),
        "status": status,
    }


def main():
    horizon = ea.horizon()
    today = datetime.date.today().isoformat()

    page = ea.fetch(URL)
    events = events_from_html(page)

    settings = parse_settings(page)
    if settings and settings.get("atts"):
        events.extend(load_more(
            settings["atts"], settings["end_date"], settings["offset"],
            settings["current_month_divider"], horizon))

    seen = set()
    records = []
    for e in events:
        url = e.get("url") or (e.get("offers") or {}).get("url")
        if not url or url in seen:
            continue
        seen.add(url)
        rec = build(e)
        if not rec:
            continue
        if rec["start"][:10] < today:
            continue
        records.append(rec)

    ea.emit(records)


if __name__ == "__main__":
    main()
