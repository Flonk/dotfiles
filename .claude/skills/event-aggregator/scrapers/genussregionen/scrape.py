import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

URL = "https://festival.genussregionen.at/"


def main():
    page = ea.fetch(URL)

    m = re.search(
        r"Save the Date (\d{4}):</strong><br>[^<]*<strong>"
        r"(\d{1,2})\.\s*bis\s*(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)</strong>\s*im\s*([^<]+)",
        page,
    )
    if not m:
        ea.emit([])
        return

    year, d1, d2, month_name, venue = m.groups()
    mon = ea.MON.get(month_name.strip()) or ea.MON.get(month_name.strip()[:3])
    venue = venue.strip()
    if not mon:
        ea.emit([])
        return

    start = f"{int(year):04d}-{mon:02d}-{int(d1):02d}"
    end = f"{int(year):04d}-{mon:02d}-{int(d2):02d}"

    title_m = re.search(r"<h1>\s*GENUSS-FESTIVAL\s*\d{4}\s*</h1>", page)
    title = f"GENUSS-FESTIVAL {year}"

    rec = {
        "source": "genussregionen",
        "source_id": f"genuss-festival-{year}",
        "url": URL,
        "title": title,
        "start": start,
        "end": end,
        "venue": venue,
        "district": None,
        "city": "Wien",
        "address": None,
        "price_min": None,
        "price_text": None,
        "category": None,
        "description": "Kulinarikfestival der AMA Genuss Regionen im Wiener Stadtpark.",
        "status": "scheduled",
    }
    ea.emit([rec])


if __name__ == "__main__":
    main()
