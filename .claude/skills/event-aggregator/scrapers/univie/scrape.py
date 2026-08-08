import datetime
import html
import json
import re
import sys
import time

import ea

BASE = "https://kalender.univie.ac.at"
SLUG = "univie"

WEITER_RE = re.compile(
    r'class="btn-primary inline rounded px-4 py-3 font-normal float-right" href="([^"]+)"')
ROW_RE = re.compile(r'<div class="row bg-gray-lightest p-4 mb-6">')
DT_RE = re.compile(r'datetime="([0-9-]+) ([0-9:]+)"')
LINK_RE = re.compile(r'<h3 class="h5 link-text"><a href="([^"]+)">', re.S)
ID_RE = re.compile(r'tx_univieevents_pi1%5Bid%5D=(\d+)')
CATEGORY_RE = re.compile(
    r'rounded-lg border border-gray-dark btn-primary-light bg-primary-light '
    r'px-4 py-1[^"]*"[^>]*>([^<]*)<')
STATUS_MAP = {
    "https://schema.org/EventScheduled": "scheduled",
    "https://schema.org/EventCancelled": "cancelled",
    "https://schema.org/EventPostponed": "postponed",
    "https://schema.org/EventRescheduled": "postponed",
}


def section(page, name):
    m = re.search(r'###' + name + r'### begin(.*?)###' + name + r'### end', page, re.S)
    return m.group(1) if m else ""


def collect_ids_from_mainlist(main, seen):
    starts = [m.start() for m in ROW_RE.finditer(main)]
    last_date = None
    for i, s in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(main)
        block = main[s:end]
        dm = DT_RE.search(block)
        lm = LINK_RE.search(block)
        if not lm:
            continue
        href = html.unescape(lm.group(1))
        idm = ID_RE.search(href)
        if not idm:
            continue
        eid = idm.group(1)
        if dm:
            last_date = dm.group(1)
        if eid not in seen:
            seen[eid] = BASE + href
    return last_date


def collect_ids_from_links(text, seen):
    for m in re.finditer(r'<a href="([^"]*einzelansicht[^"]*id%5D=(\d+)[^"]*)"', text):
        href, eid = html.unescape(m.group(1)), m.group(2)
        if eid not in seen:
            seen[eid] = BASE + href


def crawl_list():
    seen = {}
    url = BASE + "/"
    horizon = ea.horizon().isoformat()
    for _ in range(120):
        try:
            page = ea.fetch(url)
        except Exception as e:
            sys.stderr.write(f"{url}: {e}\n")
            break
        if url == BASE + "/":
            collect_ids_from_links(section(page, "Teaser"), seen)
            collect_ids_from_links(section(page, "EXHIBITIONBOX"), seen)
        last_date = collect_ids_from_mainlist(section(page, "MAINLIST"), seen)
        m = WEITER_RE.search(page)
        if not m:
            break
        if last_date and last_date > horizon:
            break
        url = BASE + html.unescape(m.group(1))
        time.sleep(0.15)
    return seen


def parse_detail(eid, url):
    try:
        page = ea.fetch(url)
    except Exception as e:
        sys.stderr.write(f"{url}: {e}\n")
        return None
    ev = None
    for d in ea.jsonld(page):
        if d.get("@type") == "Event":
            ev = d
            break
    if not ev:
        return None

    start = ea.de_date(ev.get("startDate"))
    end = ea.de_date(ev.get("endDate")) if ev.get("endDate") else None
    if not start:
        return None
    today = datetime.date.today().isoformat()
    if (end or start)[:10] < today:
        return None

    loc = ev.get("location") or {}
    venue = loc.get("name")
    addr = loc.get("address") or {}
    postal = addr.get("postalCode")
    street = addr.get("streetAddress")
    locality = addr.get("addressLocality")
    address = ", ".join(p for p in [street, " ".join(
        x for x in [postal, locality] if x)] if p) or None
    if loc.get("@type") == "VirtualLocation" and not venue:
        venue = "Online"
    city = locality or None

    price_min = 0.0 if ev.get("isAccessibleForFree") is True else None

    cm = CATEGORY_RE.search(page)
    category = ea.text(cm.group(1)) if cm else None

    status = STATUS_MAP.get(ev.get("eventStatus"), "scheduled")

    return {
        "source": SLUG,
        "source_id": eid,
        "url": url,
        "title": ev.get("name"),
        "start": start,
        "end": end,
        "venue": venue,
        "district": ea.district(postal),
        "city": city,
        "address": address,
        "price_min": price_min,
        "price_text": None,
        "category": category,
        "description": ea.text(ev.get("description")),
        "status": status,
    }


def main():
    seen = crawl_list()
    records = []
    for eid, url in seen.items():
        rec = parse_detail(eid, url)
        if rec and rec.get("title"):
            records.append(rec)
        time.sleep(0.1)
    ea.emit(records)


if __name__ == "__main__":
    main()
