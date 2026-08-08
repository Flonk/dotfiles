import datetime
import re
import sys
from concurrent.futures import ThreadPoolExecutor

import ea

BASE = "https://www.stadtkinowien.at"
VENUE = "Stadtkino im Künstlerhaus"
ADDRESS = "Akademiestraße 13, 1010 Wien"
DISTRICT = 1010

COLUMN_RE = re.compile(r'<div class="film-column">(.*?)</div><!-- film-column -->', re.S)
ARTICLE_RE = re.compile(r'<article class="film">(.*?)</article>', re.S)
TIME_RE = re.compile(r'<div class="film-info-box content">(\d{1,2}:\d{2})</div>')
SHOWID_RE = re.compile(r'show_id=(\d+)')
TITLE_RE = re.compile(
    r'<a href="(https://www\.stadtkinowien\.at/film/[^"]+/)"><h1>(.*?)</h1></a>', re.S)
PARA_RE = re.compile(r'<p>(.*?)</p>', re.S)
REGIE_RE = re.compile(r'<span class="regie">(.*?)</span>', re.S)
SMALL_RE = re.compile(r'<div class="film-info-box content small">([^<]*)</div>')
SKIP_TITLES = {"geschlossene veranstaltung"}

DETAIL_IMAGE_RE = re.compile(
    r'<img[^>]*src="([^"]+)"[^>]*class="[^"]*attachment-details')


def fetch_detail_image(url):
    try:
        html = ea.fetch(url, timeout=60)
    except Exception as e:
        sys.stderr.write(f"detail fetch failed {url}: {e}\n")
        return None
    im = DETAIL_IMAGE_RE.search(html)
    return im.group(1) if im else None


def parse_day_page(html, day):
    records = []
    cols = COLUMN_RE.findall(html)
    for offset, col in enumerate(cols[:3]):
        date = day + datetime.timedelta(days=offset)
        for art in ARTICLE_RE.findall(col):
            tm = TITLE_RE.search(art)
            if not tm:
                continue
            url, title = tm.group(1), ea.text(tm.group(2))
            if not title or title.strip().lower() in SKIP_TITLES:
                continue
            timem = TIME_RE.search(art)
            if timem:
                hh, mm = timem.group(1).split(":")
                start = f"{date.isoformat()}T{int(hh):02d}:{mm}"
            else:
                start = date.isoformat()
            sidm = SHOWID_RE.search(art)
            source_id = sidm.group(1) if sidm else f"{url.rstrip('/').rsplit('/', 1)[-1]}-{start}"

            paras = PARA_RE.findall(art)
            meta_html = paras[0] if paras else ""
            rm = REGIE_RE.search(meta_html)
            director = ea.text(rm.group(1)) if rm else None
            rest = ea.text(REGIE_RE.sub("", meta_html)) if meta_html else None
            description = ea.text(paras[1]) if len(paras) > 1 else None
            notes = [t for t in (ea.text(p) for p in paras[2:]) if t]

            versions = [v for v in (ea.text(x) for x in SMALL_RE.findall(art)) if v]

            extra = {}
            if director:
                extra["director"] = director
            if rest:
                extra["origin_year_runtime"] = rest
            if versions:
                extra["version"] = versions[0]
            if notes:
                extra["notes"] = notes

            records.append({
                "source": "stadtkinowien",
                "source_id": source_id,
                "url": url,
                "title": title,
                "start": start,
                "end": None,
                "venue": VENUE,
                "district": DISTRICT,
                "city": "Wien",
                "address": ADDRESS,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": description,
                "status": "scheduled",
                "extra": extra or None,
            })
    return records


def main():
    cutoff = ea.horizon()
    day = datetime.date.today()
    records = []
    seen = set()
    while day <= cutoff:
        url = f"{BASE}/programm/dat/{day.strftime('%Y%m%d')}/"
        try:
            html = ea.fetch(url, timeout=60)
        except Exception as e:
            sys.stderr.write(f"fetch failed {url}: {e}\n")
            day += datetime.timedelta(days=3)
            continue
        for rec in parse_day_page(html, day):
            if rec["source_id"] in seen:
                continue
            seen.add(rec["source_id"])
            records.append(rec)
        day += datetime.timedelta(days=3)

    urls = sorted({r["url"] for r in records})
    images = {}
    with ThreadPoolExecutor(max_workers=10) as ex:
        for url, image in zip(urls, ex.map(fetch_detail_image, urls)):
            images[url] = image
    for r in records:
        r["image"] = images.get(r["url"])

    ea.emit(records)


if __name__ == "__main__":
    main()
