import datetime
import html
import re

import ea

SLUG = "wien_gv_sommerkinos"
URL = "https://www.wien.gv.at/kultur/sommerkinos"


def clean(s):
    return ea.text(s)


def parse_day_month(s, fallback_month=None):
    m = re.search(r"(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)?", s)
    if not m:
        return None
    day = int(m.group(1))
    mon_name = m.group(2)
    month = None
    if mon_name:
        cap = mon_name.strip().capitalize()
        month = ea.MON.get(cap) or ea.MON.get(cap[:3])
    if month is None:
        month = fallback_month
    return day, month


def extract_time(t):
    m = re.search(r"(\d{1,2})[.:](\d{2})\s*Uhr", t)
    if not m:
        return None
    return f"{int(m.group(1)):02d}:{m.group(2)}"


def extract_year(t, default_year):
    m = re.search(r"\b(20\d{2})\b", t)
    return int(m.group(1)) if m else default_year


def parse_termin(raw_text, default_year):
    t = clean(raw_text) or ""
    t = re.sub(r"^Termine?:\s*", "", t).strip()
    time_ = extract_time(t)
    y = extract_year(t, default_year)
    if re.search(r"\bbis\b", t):
        left, right = re.split(r"\bbis\b", t, maxsplit=1)
        left = re.sub(r".*?\bvon\b\s*", "", left) if "von" in left else left
        rd = parse_day_month(right)
        ld = parse_day_month(left, fallback_month=rd[1] if rd else None)
        if not ld or not rd or ld[1] is None or rd[1] is None:
            return []
        start = f"{y:04d}-{ld[1]:02d}-{ld[0]:02d}"
        end = f"{y:04d}-{rd[1]:02d}-{rd[0]:02d}"
        if time_:
            start += f"T{time_}"
            end += f"T{time_}"
        return [(start, end)]
    parts = [p.strip() for p in re.split(r",|\bund\b", t) if p.strip()]
    parsed = [parse_day_month(p) for p in parts]
    for i in range(len(parsed) - 1, -1, -1):
        if parsed[i] and parsed[i][1] is None:
            for j in range(i + 1, len(parsed)):
                if parsed[j] and parsed[j][1] is not None:
                    parsed[i] = (parsed[i][0], parsed[j][1])
                    break
    out = []
    for d in parsed:
        if not d or d[1] is None:
            continue
        s = f"{y:04d}-{d[1]:02d}-{d[0]:02d}"
        if time_:
            s += f"T{time_}"
        out.append((s, None))
    return out


def parse_date_range(date_text, default_year):
    y = extract_year(date_text, default_year)
    parts = [p.strip() for p in re.split(r",|\bund\b", date_text) if p.strip()]
    parsed = [parse_day_month(p) for p in parts]
    for i in range(len(parsed) - 1, -1, -1):
        if parsed[i] and parsed[i][1] is None:
            for j in range(i + 1, len(parsed)):
                if parsed[j] and parsed[j][1] is not None:
                    parsed[i] = (parsed[i][0], parsed[j][1])
                    break
    dates = [f"{y:04d}-{d[1]:02d}-{d[0]:02d}" for d in parsed if d and d[1] is not None]
    if not dates:
        return None, None
    return min(dates), max(dates)


def district_of(addr):
    if not addr:
        return None
    m = re.match(r"^(\d{1,2})\.,", addr.strip())
    if not m:
        return None
    n = int(m.group(1))
    if 1 <= n <= 23:
        return 1000 + n * 10
    return None


def extract_link(li_html):
    m = re.search(r'<a\s+href="([^"]+)"[^>]*>(.*?)</a>', li_html, re.S)
    if not m:
        return None, None
    return m.group(1), clean(m.group(2))


def ort_venue_address(li_html):
    text_raw = re.sub(r"^Ort:\s*", "", li_html)
    href, link_text = extract_link(text_raw)
    rest = re.sub(r'<a\s+href="[^"]+"[^>]*>.*?</a>', "", text_raw, flags=re.S)
    rest = clean(rest)
    rest = re.sub(r"^[,\s]+|[,\s]+$", "", rest or "") or None
    address = link_text
    venue = rest
    if not address and not venue:
        venue = clean(text_raw)
    return venue, address


def top_level_items(ul_inner):
    items = []
    depth = 0
    start = None
    i = 0
    for m in re.finditer(r"<li>|</li>|<ul>|</ul>", ul_inner):
        tag = m.group(0)
        if tag == "<li>" and depth == 0:
            start = m.end()
        elif tag == "</li>" and depth == 0 and start is not None:
            items.append(ul_inner[start:m.start()])
            start = None
        elif tag == "<ul>":
            depth += 1
        elif tag == "</ul>":
            depth -= 1
    return items


def get_default_year(page):
    m = re.search(r"Sommerkinos und Filmfestivals (\d{4})", page)
    if m:
        return int(m.group(1))
    return datetime.date.today().year


def get_category(page):
    m = re.search(r"<wm-tag-list>.*?</wm-tag-list>", page, re.S)
    if not m:
        return None
    anchors = re.findall(r"<a\s+href=\"[^\"]*\"[^>]*>(.*?)</a>", m.group(0), re.S)
    if not anchors:
        return None
    return clean(anchors[-1])


def parse_blocks(page):
    m = re.search(r'class="section-content">(.*?)Weiterführende Informationen', page, re.S)
    body = m.group(1) if m else page
    matches = list(re.finditer(r'<h2><span\s+id="([^"]+)"[^>]*>(.*?)</span></h2>', body, re.S))
    blocks = []
    for i, mm in enumerate(matches):
        block_id = mm.group(1)
        title = clean(mm.group(2))
        content_start = mm.end()
        content_end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        blocks.append((block_id, title, body[content_start:content_end]))
    return blocks


def main():
    page = ea.fetch(URL, cache="page.html")
    default_year = get_default_year(page)
    category = get_category(page)
    today = datetime.date.today()
    cutoff = ea.horizon()

    records = []
    for block_id, title, content in parse_blocks(page):
        pm = re.search(r"<p>(.*?)</p>", content, re.S)
        description = clean(pm.group(1)) if pm else None

        um = re.search(r"<ul>(.*)</ul>", content, re.S)
        if not um:
            continue
        li_items = top_level_items(um.group(1))
        if not li_items:
            continue

        link_url, _ = extract_link(li_items[0])
        link_url = link_url or f"{URL}#{block_id}"

        price_min = None
        price_text = None
        occs = []

        for li in li_items[1:]:
            plain = clean(li) or ""
            if re.match(r"Termine?:", plain) and "<ul>" not in li:
                for start, end in parse_termin(li, default_year):
                    occs.append((start, end, None, None))
            elif re.match(r"Termine? und Orte", plain) and "<ul>" in li:
                nested = re.search(r"<ul>(.*)</ul>", li, re.S)
                if nested:
                    for sub_li in top_level_items(nested.group(1)):
                        date_part, _, rest = sub_li.partition(":")
                        date_text = clean(date_part) or ""
                        start, end = parse_date_range(date_text, default_year)
                        venue, address = ort_venue_address("Ort: " + rest)
                        if start:
                            occs.append((start, end, venue, address))
            elif re.match(r"Ort\b", plain) and "Schlechtwetter" not in plain:
                venue, address = ort_venue_address(li)
                for j in range(len(occs)):
                    s, e, v, a = occs[j]
                    if v is None and a is None:
                        occs[j] = (s, e, venue, address)
            elif re.search(r"eintritt frei|gratis|kostenlos", plain, re.I):
                price_min, price_text = 0.0, plain

        n = len(occs)
        for idx, (start, end, venue, address) in enumerate(occs):
            end_check = end or start
            end_date = end_check[:10]
            if datetime.date.fromisoformat(end_date) < today:
                continue
            if datetime.date.fromisoformat(start[:10]) > cutoff:
                continue
            source_id = block_id if n == 1 else f"{block_id}-{idx}"
            records.append({
                "source": SLUG,
                "source_id": source_id,
                "url": link_url,
                "title": title,
                "start": start,
                "end": end,
                "venue": venue,
                "district": district_of(address),
                "city": "Wien",
                "address": address,
                "price_min": price_min,
                "price_text": price_text,
                "category": category,
                "description": description,
            })

    ea.emit(records)


if __name__ == "__main__":
    main()
