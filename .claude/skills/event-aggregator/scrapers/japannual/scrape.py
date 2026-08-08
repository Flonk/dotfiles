import datetime
import re
import sys

import ea

URL = "https://www.japannual.at/"


def main():
    page = ea.fetch(URL)
    t = ea.text(page)
    if not t:
        return

    m = re.search(
        r"(?:Die\s+(\d+)\.\s*Japanischen Filmtage[^.]*?)?von\s+(\d{1,2})\.\s*bis\s*"
        r"(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s+(\d{4})", t)
    if not m:
        sys.stderr.write("no festival dates found on page\n")
        return
    edition, day_from, day_to, month_name, year = m.groups()
    month = ea.MON.get(month_name) or ea.MON.get(month_name[:3])
    if not month:
        sys.stderr.write(f"unknown month name {month_name!r}\n")
        return
    year = int(year)
    start = f"{year:04d}-{month:02d}-{int(day_from):02d}"
    end = f"{year:04d}-{month:02d}-{int(day_to):02d}"

    if end < datetime.date.today().isoformat():
        return

    addr_m = re.search(r"FILMCASINO\s+([A-Za-zÄÖÜäöüß.\s]+\d+,\s*1050\s*WIEN)", t, re.I)
    address = addr_m.group(1).strip().title() if addr_m else "Margaretenstrasse 78, 1050 Wien"

    price_m = re.search(
        r"Preise.*?Festival Pass:\s*.\s*[0-9.,]+\s*,?-?", t)
    price_text = price_m.group(0) if price_m else None
    price_min, _ = ea.price(price_text) if price_text else (None, None)

    desc_m = re.search(
        r"(Die\s+\d+\.\s*Japanischen Filmtage in Wien[^!]*!)", t)
    description = desc_m.group(1) if desc_m else None

    title = f"Japannual {year}" + (f" – {edition}. Japanische Filmtage in Wien" if edition else "")

    rec = {
        "source": "japannual",
        "source_id": f"japannual-{year}",
        "url": URL,
        "title": title,
        "start": start,
        "end": end,
        "venue": "Filmcasino",
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
