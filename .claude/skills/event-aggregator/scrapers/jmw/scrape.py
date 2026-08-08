import datetime
import json
import re
import urllib.parse
import urllib.request

import ea

SLUG = "jmw"
BASE = "https://www.jmw.at"
APP_URL = (BASE + "/jart/prj3/jmw/resources/dbcon-def/reports/apps/"
           "ausstellung/ausstellung_liste/ausstellung_liste.jartc")

VENUE_INFO = {
    "Museum Dorotheergasse": ("Dorotheergasse 11, 1010 Wien", 1010),
    "Museum Judenplatz": ("Judenplatz 8, 1010 Wien", 1010),
    "Project Space - Dorotheergasse": ("Dorotheergasse 11, 1010 Wien", 1010),
}

TICKET_PRICE_MIN = 15.0
TICKET_PRICE_TEXT = "Erwachsene € 15,-"

DETAIL_TEXT_RE = re.compile(r'class="detail-text[^"]*">\s*(.*?)\s*</div>', re.S)


def fetch_list(filtertype):
    today = datetime.date.today().isoformat()
    data = {"customSort": "default", "sel-start": 0, filtertype: today}
    body = urllib.parse.urlencode({
        "cmd": "filterResults",
        "data": json.dumps(data),
    }).encode()
    req = urllib.request.Request(APP_URL, data=body, headers={
        "User-Agent": ea.UA,
        "Accept-Language": "de-AT,de;q=0.9,en;q=0.8",
        "Content-Type": "application/x-www-form-urlencoded",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        raw = r.read().decode("utf-8", "replace")
    return json.loads(raw).get("ausstellung") or []


def description_for(url):
    try:
        page = ea.fetch(url)
    except Exception:
        return None
    m = DETAIL_TEXT_RE.search(page)
    return ea.text(m.group(1)) if m else None


def build_record(item):
    cc_id = item.get("j-cc-id")
    title = ea.text(item.get("titel"))
    if not cc_id or not title:
        return None
    url = (f"{BASE}/ausstellungen/ausstellung_detail?j-cc-id={cc_id}"
           "&j-cc-name=hybrid-content&j-cc-node=ausstellung")
    start = item.get("datum_von")
    permanent = item.get("permanent") == "ja" or item.get("permanent_online") == "ja"
    end = None if permanent else item.get("datum_bis")

    ort = (item.get("ort_name") or "").strip()
    is_online = ort.upper() == "ONLINE"
    address, district = VENUE_INFO.get(ort, (None, None))

    if is_online:
        venue, price_min, price_text = None, None, None
    else:
        venue = ort or None
        price_min, price_text = TICKET_PRICE_MIN, TICKET_PRICE_TEXT

    rec = {
        "source": SLUG,
        "source_id": cc_id,
        "url": url,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": district,
        "city": None if is_online else "Wien",
        "address": address,
        "price_min": price_min,
        "price_text": price_text,
        "category": "Ausstellung",
        "description": description_for(url),
    }
    if permanent:
        rec["extra"] = {"permanent": True}
    return rec


def main():
    items = {}
    for filtertype in ("aktuell", "vorschau"):
        for item in fetch_list(filtertype):
            cc_id = item.get("j-cc-id")
            if cc_id:
                items[cc_id] = item

    records = []
    for item in items.values():
        rec = build_record(item)
        if rec and rec.get("start"):
            records.append(rec)

    ea.emit(records)


if __name__ == "__main__":
    main()
