import datetime
import re
import sys
import urllib.parse
import urllib.request

import ea

BASE = "https://www.josefstadt.org/webshop/shop/spielplan_stuecke.aspx"

VENUES = {
    "js": ("Theater in der Josefstadt", "Josefstädter Straße 26, 1080 Wien", 1080),
    "ks": ("Kammerspiele der Josefstadt", "Rotenturmstraße 20, 1010 Wien", 1010),
}

BLOCK_RE = re.compile(r'<div class="spielplan-grid-item spielplan-grid-column-(js|ks)"')
FIELD_RE = re.compile(
    r'<time[^>]*datetime="(?P<date>\d{4}-\d{2}-\d{2})"[^>]*>.*?'
    r'<h3[^>]*>\s*(?:<a href=\'(?P<url>[^\']+)\'[^>]*>(?P<title>[^<]+)|(?P<notitle>[^<]+))'
    r'.*?(?:<span[^>]*class="time[^"]*"[^>]*>(?P<time>[\d.]+)\s*Uhr</span>)?'
    r'.*?(?:<ul[^>]*class="categories[^"]*"[^>]*>(?P<cats>.*?)</ul>)?'
    r'.*?(?:<a href="[^"]*intEventID=(?P<eventid>\d+)[^"]*"[^>]*class="karten)?',
    re.S,
)


def month_options(html):
    opts = re.findall(r'<option value="([^"]*)">([^<]+)</option>', html)
    out = []
    for val, _ in opts:
        val = val.strip()
        if not val:
            continue
        d, m, y = val.split(".")
        out.append((val, datetime.date(int(y), int(m), int(d))))
    return out


def field(html, name):
    m = re.search(name + r'[^>]*value="([^"]*)"', html)
    return m.group(1) if m else ""


def fetch_month(month_val, base_html):
    vs = field(base_html, "__VIEWSTATE")
    vsg = field(base_html, "__VIEWSTATEGENERATOR")
    ev = field(base_html, "__EVENTVALIDATION")
    data = {
        "__EVENTTARGET": "ctl00$ContentPlaceHolder1$ctlMonateListe$ctlMonthDropdown",
        "__EVENTARGUMENT": "",
        "__VIEWSTATE": vs,
        "__VIEWSTATEGENERATOR": vsg,
        "__EVENTVALIDATION": ev,
        "ctl00$ContentPlaceHolder1$ctlMonateListe$ctlMonthDropdown": month_val,
        "ctl00$ContentPlaceHolder1$ctlStueckeListe$ctlEventSeries": " ",
    }
    body = urllib.parse.urlencode(data).encode()
    req_headers = {"Content-Type": "application/x-www-form-urlencoded", "Referer": BASE}
    req = urllib.request.Request(BASE, data=body, headers={"User-Agent": ea.UA, **req_headers})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def parse_blocks(html):
    idxs = [m.start() for m in BLOCK_RE.finditer(html)]
    cols = [BLOCK_RE.match(html, i).group(1) for i in idxs]
    idxs.append(len(html))
    for k, i in enumerate(idxs[:-1]):
        yield cols[k], html[i:idxs[k + 1]]


def parse_price(cats_html):
    if not cats_html:
        return None
    vals = [float(v) for v in re.findall(r"<li[^>]*>(\d+(?:[.,]\d+)?)</li>", cats_html)]
    return min(vals) if vals else None


def parse_events(html):
    for col, block in parse_blocks(html):
        m = FIELD_RE.search(block)
        if not m or not m.group("url"):
            continue
        title = m.group("title").strip()
        date = m.group("date")
        time_s = m.group("time")
        start = f"{date}T{time_s.replace('.', ':')}" if time_s else date
        detail_url = m.group("url")
        event_id = m.group("eventid")
        venue, address, district = VENUES[col]
        author_m = re.search(r'ctlBesetzung_\d+"[^>]*>([^<]*)<', block)
        author = (author_m.group(1).strip() if author_m else "") or None
        comment_m = re.search(r'ctlComment_\d+"[^>]*>(.*?)</p>', block, re.S)
        comment = ea.text(comment_m.group(1)) if comment_m else None
        price_min = parse_price(m.group("cats"))
        source_id = event_id or f"{detail_url}#{start}"
        yield {
            "source": "josefstadt",
            "source_id": source_id,
            "url": detail_url,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": district,
            "city": "Wien",
            "address": address,
            "price_min": price_min,
            "price_text": None,
            "category": None,
            "description": " – ".join(x for x in (author, comment) if x) or None,
        }


def main():
    horizon = ea.horizon()
    base_html = ea.fetch(BASE)
    seen = set()
    records = list(parse_events(base_html))

    months = month_options(base_html)
    for val, mdate in months:
        if mdate > horizon:
            continue
        html = fetch_month(val, base_html)
        records.extend(parse_events(html))

    out = []
    for r in records:
        sd = r["start"][:10]
        if sd > horizon.isoformat():
            continue
        if r["source_id"] in seen:
            continue
        seen.add(r["source_id"])
        out.append(r)

    ea.emit(out)


if __name__ == "__main__":
    main()
