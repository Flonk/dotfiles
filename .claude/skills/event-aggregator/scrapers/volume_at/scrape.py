import concurrent.futures
import datetime
import html
import re
import sys
import time

import ea

BASE = "https://www.volume.at"
LIST = BASE + "/events/{}/"

DETAIL_WORKERS = 8
DETAIL_RETRIES = 2
DETAIL_TIMEOUT = 12
RUN_BUDGET = 220  # seconds; check.py hard-kills at 300, leave margin

TIME_BLOCK_RE = re.compile(r'meta__time">(.*?)</div>', re.S)
TIME_ITEM_RE = re.compile(r'<b>([^<]*)</b>\s*([^<]*)</span>')
ADDR_BLOCK_RE = re.compile(
    r'<address class="item__location[^"]*">.*?</address>', re.S)

HEADER_RE = re.compile(
    r'<span class="day">(\d+)</span>\s*<div>\s*<span class="weekday">[^<]*</span>\s*'
    r'<span class="month">([^<]*)</span>', re.S)
ITEM_RE = re.compile(
    r'<article[^>]*\bitem--event\b[^>]*data-content-id="(\d+)".*?</article>', re.S)
TITLE_RE = re.compile(
    r'<h2[^>]*class="item__title[^"]*">\s*<a href="([^"]+)"[^>]*>\s*<span>\s*(.*?)\s*</span>', re.S)
CANCEL_RE = re.compile(r'badge[^"]*"[^>]*>\s*abgesagt\s*<', re.I)
TYPE_RE = re.compile(r'item__eventtype">([^<]*)<')
LOC_RE = re.compile(r'item__location[^"]*"[^>]*>\s*([^<]*?)\s*</a>')
ADDR_RE = re.compile(r'location__address">\s*([^<]*?)\s*<')
OFFERS_RE = re.compile(r'item__offers">(.*?)</div>', re.S)

MONTHS = ea.MON

COMBINED = re.compile(
    r'(?P<header><span class="day">\d+</span>\s*<div>\s*<span class="weekday">[^<]*</span>\s*'
    r'<span class="month">[^<]*</span>)'
    r'|(?P<item><article[^>]*\bitem--event\b[^>]*data-content-id="\d+".*?</article>)', re.S)


def parse_page(page, cursor):
    last = cursor - datetime.timedelta(days=1)
    out = []
    dates_seen = []
    for m in COMBINED.finditer(page):
        if m.group("header"):
            hm = HEADER_RE.match(m.group("header"))
            if not hm:
                continue
            day = int(hm.group(1))
            month = MONTHS.get(hm.group(2).strip())
            if not month:
                continue
            year = last.year
            try:
                dt = datetime.date(year, month, day)
            except ValueError:
                continue
            if dt < last:
                dt = datetime.date(year + 1, month, day)
            last = dt
            dates_seen.append(dt)
        else:
            block = m.group("item")
            tm = TITLE_RE.search(block)
            if not tm:
                continue
            url = tm.group(1)
            if url.startswith("/"):
                url = BASE + url
            title = ea.text(html.unescape(tm.group(2)))
            if not title:
                continue
            cancelled = bool(CANCEL_RE.search(block))
            tym = TYPE_RE.search(block)
            category = ea.text(tym.group(1)) if tym else None
            locm = LOC_RE.search(block)
            venue = ea.text(locm.group(1)) if locm else None
            addrm = ADDR_RE.search(block)
            addr = ea.text(addrm.group(1)) if addrm else None
            offm = OFFERS_RE.search(block)
            price_min = price_text = None
            if offm:
                price_min, price_text = ea.price(offm.group(1))
            idm = re.search(r'data-content-id="(\d+)"', block)
            src_id = idm.group(1) if idm else url
            out.append({
                "source": "volume_at",
                "source_id": src_id,
                "url": url,
                "title": title,
                "start": last.isoformat(),
                "end": None,
                "venue": venue,
                "district": ea.district(addr),
                "city": "Wien" if addr == "Wien" else None,
                "address": None,
                "price_min": price_min,
                "price_text": price_text,
                "category": category,
                "description": None,
                "status": "cancelled" if cancelled else "scheduled",
            })
    return out, dates_seen


def parse_detail(url, deadline):
    """Fetch a detail page and pull start time, street address and district.

    Returns a dict with any subset of start_time/address/district filled in;
    missing pieces are simply absent (never guessed). Any fetch/parse
    failure yields an empty dict so the listing-derived record is used as-is.
    """
    out = {}
    page = None
    for attempt in range(DETAIL_RETRIES):
        if time.time() > deadline:
            return out
        try:
            page = ea.fetch(url, timeout=DETAIL_TIMEOUT)
            break
        except Exception:
            if attempt + 1 < DETAIL_RETRIES:
                time.sleep(0.3 * (attempt + 1))
    if page is None:
        return out

    tb = TIME_BLOCK_RE.search(page)
    if tb:
        labels = {}
        for label, val in TIME_ITEM_RE.findall(tb.group(1)):
            label = label.strip().rstrip(":")
            val = val.strip()
            labels[label] = val
        chosen = labels.get("Beginn") or labels.get("Einlass")
        if chosen:
            tm = re.search(r"(\d{1,2})[:.](\d{2})", chosen)
            if tm:
                out["start_time"] = f"{int(tm.group(1)):02d}:{tm.group(2)}"

    street = postal = locality = None
    for node in ea.jsonld(page):
        if "postalCode" in node or "streetAddress" in node:
            street = node.get("streetAddress") or street
            postal = node.get("postalCode") or postal
            locality = node.get("addressLocality") or locality
            break

    if street and postal and locality:
        out["address"] = f"{street}, {postal} {locality}"
    elif street or postal or locality:
        out["address"] = ", ".join(p for p in (street, postal, locality) if p)
    else:
        am = ADDR_BLOCK_RE.search(page)
        if am:
            addr_text = ea.text(am.group(0))
            if addr_text:
                title_m = re.search(r'address__title">\s*([^<]*?)\s*<', am.group(0))
                venue_name = ea.text(title_m.group(1)) if title_m else None
                if venue_name and addr_text.startswith(venue_name):
                    addr_text = addr_text[len(venue_name):].strip(" ,")
                if addr_text:
                    out["address"] = addr_text
                pm = re.search(r"\b(\d{4,5})\b", addr_text or "")
                if pm:
                    postal = pm.group(1)

    if postal:
        try:
            pc = int(postal)
            if 1010 <= pc <= 1230:
                out["district"] = pc
        except ValueError:
            pass

    return out


def enrich(records, deadline):
    ex = concurrent.futures.ThreadPoolExecutor(max_workers=DETAIL_WORKERS)
    try:
        futs = {ex.submit(parse_detail, r["url"], deadline): r for r in records}
        remaining = max(deadline - time.time(), 0)
        done, not_done = concurrent.futures.wait(
            futs, timeout=remaining, return_when=concurrent.futures.ALL_COMPLETED)
        for fut in not_done:
            sys.stderr.write(f"detail timed out {futs[fut]['url']}\n")
        for fut in done:
            r = futs[fut]
            try:
                extra = fut.result()
            except Exception as e:
                sys.stderr.write(f"detail failed {r['url']}: {e}\n")
                continue
            t = extra.get("start_time")
            if t:
                r["start"] = f"{r['start']}T{t}"
            if extra.get("address"):
                r["address"] = extra["address"]
            if extra.get("district"):
                r["district"] = extra["district"]
    finally:
        ex.shutdown(wait=False, cancel_futures=True)
    return records


def main():
    deadline = time.time() + RUN_BUDGET
    cutoff = ea.horizon()
    cursor = datetime.date.today()
    seen_ids = set()
    records = []
    for _ in range(120):
        if time.time() > deadline:
            sys.stderr.write("listing walk hit run budget, stopping early\n")
            break
        url = LIST.format(cursor.isoformat())
        page = None
        for attempt in range(DETAIL_RETRIES):
            try:
                page = ea.fetch(url, timeout=DETAIL_TIMEOUT)
                break
            except Exception as e:
                if attempt + 1 < DETAIL_RETRIES:
                    time.sleep(0.3 * (attempt + 1))
                else:
                    sys.stderr.write(f"fetch failed {url}: {e}\n")
        if page is None:
            break
        items, dates_seen = parse_page(page, cursor)
        if not dates_seen:
            break
        for r in items:
            if r["source_id"] in seen_ids:
                continue
            seen_ids.add(r["source_id"])
            records.append(r)
        cursor = max(dates_seen) + datetime.timedelta(days=1)
        if cursor > cutoff:
            break
    enrich(records, deadline)
    ea.emit(records)


if __name__ == "__main__":
    main()
