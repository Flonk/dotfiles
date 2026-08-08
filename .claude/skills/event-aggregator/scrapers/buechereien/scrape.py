import concurrent.futures
import datetime
import json
import re
import time
import urllib.parse
import urllib.request

import ea

SLUG = "buechereien"
BASE = "https://buechereien.wien.gv.at/"
DATA_URL = BASE + "Portals/0/Files/stb_va/stb_va.json"
FALLBACK_URL = "https://buechereien.wien.gv.at/veranstaltungen"

ADDR_RE = re.compile(r"Adresse:\s*([^,<]+),\s*(\d{4})\s*Wien")


def fetch_retry(url, timeout=20, tries=4, deadline_s=60):
    delay = 1.5
    deadline = time.time() + deadline_s
    last = None
    for _ in range(tries):
        try:
            return ea.fetch(url, timeout=timeout)
        except Exception as e:
            last = e
            if time.time() > deadline:
                break
            time.sleep(delay)
            delay *= 2
    raise last


def branch_info(zw_web):
    if not zw_web:
        return None, None
    url = BASE + urllib.parse.quote(zw_web, safe="/")
    try:
        raw = fetch_retry(url, timeout=20, tries=3, deadline_s=40)
    except Exception:
        return None, None
    m = ADDR_RE.search(raw)
    if not m:
        return None, None
    street = m.group(1).strip()
    plz = m.group(2)
    return street, ea.district(plz)


def main():
    raw = fetch_retry(DATA_URL, timeout=30, tries=5, deadline_s=90)
    data = json.loads(raw)["data"]

    today = datetime.date.today()
    cutoff = ea.horizon()

    zw_webs = sorted({r.get("zw_web") for r in data if r.get("zw_web")})
    branches = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(branch_info, z): z for z in zw_webs}
        for fut in concurrent.futures.as_completed(futs):
            branches[futs[fut]] = fut.result()

    records = []
    for r in data:
        begin = (r.get("beginndatum") or "")[:16].replace(" ", "T")
        if not begin:
            continue
        try:
            d = datetime.date.fromisoformat(begin[:10])
        except ValueError:
            continue
        if d < today or d > cutoff:
            continue

        end = None
        endraw = r.get("enddatum") or ""
        if endraw and endraw[:10] == begin[:10] and endraw[:16].replace(" ", "T") != begin:
            end = endraw[:16].replace(" ", "T")

        title = r.get("titel") or None
        if not title:
            continue
        vast_id = str(r.get("vast_id") or "")

        links = []
        try:
            links = json.loads(r.get("url") or "[]")
        except Exception:
            links = []
        detail_url = None
        for link in links:
            if link.get("type") == "pretix" and link.get("url"):
                detail_url = link["url"]
                break
        zw_web = r.get("zw_web")
        branch_url = BASE + urllib.parse.quote(zw_web, safe="/") if zw_web else None
        url = detail_url or branch_url or FALLBACK_URL

        cats = []
        try:
            cats = [c.get("label") for c in json.loads(r.get("kategorie") or "[]") if c.get("label")]
        except Exception:
            cats = []
        category = ", ".join(cats) if cats else None

        description = ea.text(r.get("programm"))
        price_min, price_text = ea.price(r.get("programm"))
        street, district = branches.get(zw_web, (None, None))

        records.append({
            "source": SLUG,
            "source_id": vast_id or url,
            "url": url,
            "title": title,
            "start": begin,
            "end": end,
            "venue": r.get("ort") or None,
            "district": district,
            "city": "Wien",
            "address": street,
            "price_min": price_min,
            "price_text": price_text,
            "category": category,
            "description": description,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
