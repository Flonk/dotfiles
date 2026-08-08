import re

import ea

SLUG = "viecc"
URL = "https://www.viecc.com/"

DATE_RANGE_RE = re.compile(
    r"(\d{1,2})\.\s*[–‑-]\s*(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s*(\d{4})")
HOURS_RE = re.compile(
    r"Samstag:\s*(\d{1,2}):(\d{2})\s*[–‑-]\s*\d{1,2}:\d{2}\s*Uhr\s*"
    r"Sonntag:\s*\d{1,2}:\d{2}\s*[–‑-]\s*(\d{1,2}):(\d{2})\s*Uhr")
ADDR_RE = re.compile(r"([A-ZÄÖÜ][\wäöüÄÖÜß.\- ]+?\s\d+[a-zA-Z]?),\s*(1\d{3})\s*Wien")
IMG_RE = re.compile(r'og:image"\s+content="([^"]+)"')
DESC_RE = re.compile(r'name="description"\s+content="([^"]+)"')


def prices(text):
    out = []
    for m in re.finditer(
            r"([A-Za-zÄÖÜäöü][A-Za-zÄÖÜäöü \-]{2,40}?)\s*(?:\|\s*)+€\s*(\d+)", text):
        label, val = m.group(1).strip(), float(m.group(2))
        if label and len(label.split()) <= 4:
            out.append((label, val))
    return out


def main():
    raw = ea.fetch(URL, timeout=60)
    flat = re.sub(r"<[^>]+>", "|", raw)
    flat = re.sub(r"\|\s*\|+", "|", flat)

    dm = DATE_RANGE_RE.search(raw)
    if not dm:
        ea.emit([])
        return
    d1, d2, month_name, year = dm.groups()
    mon = ea.MON.get(month_name.capitalize()) or ea.MON.get(month_name[:3].capitalize())
    if not mon:
        ea.emit([])
        return
    year = int(year)

    start_t, end_t = "10:00", "18:00"
    hm = HOURS_RE.search(flat.replace("‑", "-"))
    if hm:
        start_t = f"{int(hm.group(1)):02d}:{hm.group(2)}"
        end_t = f"{int(hm.group(3)):02d}:{hm.group(4)}"

    start = f"{year:04d}-{mon:02d}-{int(d1):02d}T{start_t}"
    end = f"{year:04d}-{mon:02d}-{int(d2):02d}T{end_t}"

    venue = None
    vm = re.search(r"Messe Wien,\s*Halle[^|<\n]*", flat)
    if vm:
        venue = vm.group(0).strip()

    address, district = None, None
    am = ADDR_RE.search(raw)
    if am:
        address = am.group(1).strip()
        district = ea.district(am.group(2))

    price_min, price_text = None, None
    pr = prices(flat)
    if pr:
        price_min = min(v for _, v in pr)
        price_text = " / ".join(f"{lbl} € {v:g}" for lbl, v in pr)

    image = None
    imgs = IMG_RE.findall(raw)
    if imgs:
        image = imgs[-1]

    description = None
    dm2 = DESC_RE.search(raw)
    if dm2:
        description = ea.text(dm2.group(1))

    record = {
        "source": SLUG,
        "source_id": f"viecc-{year}",
        "url": URL,
        "title": f"VIECC Vienna Comic Con {year}",
        "start": start,
        "end": end,
        "venue": venue,
        "district": district,
        "city": "Wien",
        "address": address,
        "price_min": price_min,
        "price_text": price_text,
        "category": None,
        "description": description,
        "image": image,
    }
    ea.emit([record])


if __name__ == "__main__":
    main()
