import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import ea

AJAX_URL = "https://www.admiralkino.at/wp/wp-admin/admin-ajax.php"
VENUE = "Admiral Kino"
ADDRESS = "Burggasse 119, 1070 Wien"
DISTRICT = 1070

SLUG_RE = re.compile(r"/produktion/([^/]+)/?$")
OGIMG_RE = re.compile(r'<meta property="og:image" content="([^"]+)"')
DURATION_RE = re.compile(r"(\d+)\s*Min")


def fetch_image(url):
    for attempt in range(3):
        try:
            page = ea.fetch(url, timeout=20)
            m = OGIMG_RE.search(page)
            img = m.group(1) if m else None
            # the site's own og:image says http://, which does not answer at
            # all; the identical https:// URL returns the image
            if img and img.startswith("http://www.admiralkino.at/"):
                img = "https://" + img[len("http://"):]
            return url, img
        except Exception:
            continue
    return url, None


def fetch_posts():
    req = urllib.request.Request(
        AJAX_URL,
        data=b"action=get_ajax_posts",
        headers={"User-Agent": ea.UA, "Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        raw = r.read()
    import json
    return json.loads(raw.decode("utf-8", "replace"))


def build(item):
    title = ea.text(item.get("title"))
    if not title or title.upper() == "SOMMERPAUSE":
        return None
    start = ea.de_date(f"{item.get('start_date', '')} {item.get('start_time', '')}".strip())
    if not start:
        return None
    url = item.get("url") or ""
    m = SLUG_RE.search(url)
    slug = m.group(1) if m else url
    remarks = ea.text(item.get("remarks")) or ""
    remarks = remarks.lstrip("|").strip() or None
    category = ea.text(item.get("categories"))
    lang = ea.text(item.get("language"))
    desc_parts = [p for p in (remarks, lang) if p]
    extra = {}
    dur = ea.text(item.get("duration"))
    if dur:
        m = DURATION_RE.search(dur)
        if m:
            extra["duration_min"] = int(m.group(1))
        else:
            extra["duration_text"] = dur
    return {
        "source": "admiralkino",
        "source_id": f"{slug}-{item.get('datetime')}",
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
        "category": category,
        "description": " / ".join(desc_parts) if desc_parts else None,
        "image": None,
        "status": "scheduled",
        "extra": extra or None,
    }


def main():
    try:
        items = fetch_posts()
    except Exception as e:
        sys.stderr.write(f"fetch failed: {e}\n")
        items = []
    cutoff = ea.horizon()
    records = []
    for item in items:
        rec = build(item)
        if not rec:
            continue
        start_date = rec["start"][:10]
        import datetime
        y, mo, d = (int(x) for x in start_date.split("-"))
        if datetime.date(y, mo, d) > cutoff:
            continue
        records.append(rec)

    urls = sorted({r["url"] for r in records if r.get("url")})
    images = {}
    if urls:
        with ThreadPoolExecutor(max_workers=8) as ex:
            for url, img in ex.map(fetch_image, urls):
                if img:
                    images[url] = img
    for r in records:
        r["image"] = images.get(r.get("url"))

    ea.emit(records)


if __name__ == "__main__":
    main()
