import datetime
import http.cookiejar
import re
import urllib.request

import ea

BASE = "https://www.kindermuseum.at"
SLUG = "kindermuseum"
VENUE = "ZOOM Kindermuseum"
DISTRICT = 1070
ADDRESS = "Museumsplatz 1, 1070 Wien"

# The site has no central events calendar: each "programm" section has one
# standing page describing whatever is currently on offer there. A few of
# those pages additionally carry a structured "Laufzeit:" (date range) or
# "TERMINE" (list of single dated slots) block; most don't and are simply
# continuously-running offerings.
PAGES = [
    ("/zoom_programmangebot/zoom_mitmachausstellung", "Ausstellung"),
    ("/zoom_programmangebot/zoom_atelier", "Atelier"),
    ("/zoom_programmangebot/zoom_atelier/atelier-abos", "Atelier"),
    ("/zoom_programmangebot/zoom_ozean", "Ozean"),
    ("/zoom_programmangebot/zoom_trickfilmstudio", "Trickfilmstudio"),
    ("/wiener_kindervorlesungen", "Fragwürdig? (vorm. Kindervorlesungen)"),
]

MONTH_RE = r"[A-Za-zÄÖÜäöü]{3,}"


def make_opener():
    cj = http.cookiejar.CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))


def fetch_page(opener, url, timeout=20, retries=2):
    req = urllib.request.Request(url, headers={
        "User-Agent": ea.UA, "Accept-Language": "de-AT,de;q=0.9,en;q=0.8"})
    for _ in range(retries):
        try:
            with opener.open(req, timeout=timeout) as r:
                return r.read().decode("utf-8", "replace")
        except Exception:
            continue
    return None


def extract_article(html):
    i = html.find('<article class="db-article-display')
    if i == -1:
        return None
    j = html.find("</article>", i)
    if j == -1:
        return None
    return html[i:j + len("</article>")]


def get_title(chunk):
    m = re.search(r'<h2 class="title\s*">(.*?)</h2>', chunk, re.S)
    return ea.text(m.group(1)) if m else None


def get_id(chunk):
    m = re.search(r"article_id_(\d+)", chunk)
    return m.group(1) if m else None


def get_price(text):
    m = re.search(r"(?:€|EUR)\s*(\d+(?:[.,]\d{1,2})?)", text)
    if m:
        return float(m.group(1).replace(",", ".")), m.group(0)
    if re.search(r"\bEintritt frei\b|\bkostenlos\b|\bgratis\b", text, re.I):
        return 0.0, "Eintritt frei"
    return None, None

def get_description(text):
    m = re.search(r"Reservierung erforderlich!\s*(.*)", text)
    body = m.group(1) if m else text
    return body[:600].strip() or None


def get_laufzeit(text):
    m = re.search(
        r"Laufzeit:\s*(\d{1,2}\.\s*" + MONTH_RE + r"\s*\d{4})\s*-\s*"
        r"(\d{1,2}\.\s*" + MONTH_RE + r"\s*\d{4})", text)
    if not m:
        return None, None
    return ea.de_date(m.group(1)), ea.de_date(m.group(2))


def get_year_hint(text, today):
    years = [int(y) for y in re.findall(r"\b(20\d{2})\b", text)]
    return years[0] if years else today.year


def get_termine(text, today):
    m = re.search(r"TERMINE\s*:?(.*?)(?:DAUER|Dauer:)", text, re.S)
    if not m:
        return []
    block = m.group(1)
    year = get_year_hint(text, today)
    out = []
    for dm, hh, mm in re.findall(
            r"(\d{1,2}\.\s*" + MONTH_RE + r")\s*(\d{1,2})[.:](\d{2})\s*Uhr", block):
        d = ea.de_date(dm, default_year=year)
        if not d:
            continue
        dt = datetime.date.fromisoformat(d)
        if dt < today:
            d2 = ea.de_date(dm, default_year=year + 1)
            dt2 = datetime.date.fromisoformat(d2) if d2 else None
            if dt2 and dt2 >= today:
                d, dt = d2, dt2
        out.append((f"{d}T{int(hh):02d}:{mm}", dt))
    return out


def main():
    today = datetime.date.today()
    cutoff = ea.horizon()
    records = []
    opener = make_opener()

    for path, category in PAGES:
        url = BASE + path
        html = fetch_page(opener, url)
        if not html:
            continue
        chunk = extract_article(html)
        if not chunk:
            continue
        title = get_title(chunk)
        if not title:
            continue
        text = ea.text(chunk) or ""
        price_min, price_text = get_price(text)
        description = get_description(text)
        article_id = get_id(chunk) or path

        start, end = get_laufzeit(text)
        termine = get_termine(text, today)

        if termine:
            for dt_str, dt in termine:
                if dt > cutoff:
                    continue
                records.append({
                    "source": SLUG,
                    "source_id": f"{article_id}-{dt_str}",
                    "url": url,
                    "title": title,
                    "start": dt_str,
                    "end": None,
                    "venue": VENUE,
                    "district": DISTRICT,
                    "city": "Wien",
                    "address": ADDRESS,
                    "price_min": price_min,
                    "price_text": price_text,
                    "category": category,
                    "description": description,
                    "status": "scheduled",
                })
        elif start and end:
            end_date = datetime.date.fromisoformat(end[:10])
            if end_date < today:
                continue
            records.append({
                "source": SLUG,
                "source_id": article_id,
                "url": url,
                "title": title,
                "start": start,
                "end": end,
                "venue": VENUE,
                "district": DISTRICT,
                "city": "Wien",
                "address": ADDRESS,
                "price_min": price_min,
                "price_text": price_text,
                "category": category,
                "description": description,
                "status": "scheduled",
            })
        else:
            records.append({
                "source": SLUG,
                "source_id": article_id,
                "url": url,
                "title": title,
                "start": today.isoformat(),
                "end": None,
                "venue": VENUE,
                "district": DISTRICT,
                "city": "Wien",
                "address": ADDRESS,
                "price_min": price_min,
                "price_text": price_text,
                "category": category,
                "description": description,
                "status": "scheduled",
                "extra": {"permanent": True},
            })

    ea.emit(records)


if __name__ == "__main__":
    main()
