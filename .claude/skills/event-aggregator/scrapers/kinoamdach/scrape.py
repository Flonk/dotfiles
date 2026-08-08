import re

import ea

URL = "https://www.kinoamdach.at/"


def main():
    page = ea.fetch(URL)
    t = ea.text(page)
    if not t:
        return

    m = re.search(
        r"(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s*[–-]\s*(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s+(\d{4})",
        t)
    if not m:
        return
    d1, mon1, d2, mon2, year = m.groups()
    mo1 = ea.MON.get(mon1.capitalize()) or ea.MON.get(mon1[:3].capitalize())
    mo2 = ea.MON.get(mon2.capitalize()) or ea.MON.get(mon2[:3].capitalize())
    if not (mo1 and mo2):
        return
    year = int(year)
    start = f"{year:04d}-{mo1:02d}-{int(d1):02d}"
    end = f"{year:04d}-{mo2:02d}-{int(d2):02d}"

    season_m = re.search(r"#(\d+)", t)
    season = season_m.group(1) if season_m else None
    title = f"Kino am Dach {year}" + (f" – {season}. Saison" if season else "")

    theme_m = re.search(r"unter dem Motto ([A-ZÄÖÜ ]+)\.", t)
    motto = theme_m.group(1).strip() if theme_m else None
    desc_m = re.search(r"(\d{4} widmen wir uns.*?Motto [A-ZÄÖÜ ]+\.)", t)
    description = desc_m.group(1) if desc_m else motto

    addr_m = re.search(
        r"Ort:\s*(Auf dem Dach der Hauptb[uü]cherei,\s*[^,]+,\s*1070\s*Wien)", t)
    address = addr_m.group(1).strip() if addr_m else "Urban-Loritz-Platz 2a, 1070 Wien"

    price_m = re.search(r"Eintrittspreis:\s*€\s*[0-9.,]+\s*,?-?.*?Kulturpass\]", t)
    price_text = price_m.group(0) if price_m else None
    price_min, _ = ea.price(price_text) if price_text else (None, None)

    rec = {
        "source": "kinoamdach",
        "source_id": f"kinoamdach-{year}",
        "url": "https://www.kinoamdach.at/",
        "title": title,
        "start": start,
        "end": end,
        "venue": "Kino am Dach (Hauptbücherei Wien)",
        "district": ea.district(address),
        "city": "Wien",
        "address": address,
        "price_min": price_min,
        "price_text": price_text,
        "category": None,
        "description": description,
    }
    ea.emit([rec])


if __name__ == "__main__":
    main()
