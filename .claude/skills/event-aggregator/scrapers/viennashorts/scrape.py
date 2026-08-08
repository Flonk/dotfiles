import datetime
import re

import ea

BASE = "https://www.viennashorts.com/"
TICKETS_URL = BASE + "besuch-uns/ticket-infos"


def main():
    page = ea.fetch(BASE)
    t = ea.text(page)
    if not t:
        return

    m = re.search(
        r"(\d+)\.\s*Internationales Kurzfilmfestival\s*"
        r"(\d{1,2})\.\s*[–-]\s*(\d{1,2})\.\s*([A-Za-zÄÖÜäöü]+)\s*(\d{4})", t)
    if not m:
        return
    edition, day_from, day_to, month_name, year = m.groups()
    month = ea.MON.get(month_name) or ea.MON.get(month_name[:3])
    if not month:
        return
    year = int(year)
    start = f"{year:04d}-{month:02d}-{int(day_from):02d}"
    end = f"{year:04d}-{month:02d}-{int(day_to):02d}"

    if end < datetime.date.today().isoformat():
        return

    price_min = None
    price_text = None
    try:
        tickets_page = ea.fetch(TICKETS_URL)
        tt = ea.text(tickets_page)
        amounts = re.findall(r"(\d+(?:,\d{1,2})?)\s*€\s*[–-]\s*([A-Za-zÄÖÜäöüß \"]+?Pass|[A-Za-zÄÖÜäöüß]+ Ticket|Ticket [A-Za-zÄÖÜäöüß ]+)", tt)
        if amounts:
            price_min = min(float(a.replace(",", ".")) for a, _ in amounts)
            price_text = "; ".join(f"{a} € – {n.strip()}" for a, n in amounts)
    except Exception:
        pass

    rec = {
        "source": "viennashorts",
        "source_id": f"viennashorts-{year}",
        "url": BASE,
        "title": f"Vienna Shorts {year} – {edition}. Internationales Kurzfilmfestival",
        "start": start,
        "end": end,
        "venue": "diverse Spielorte (u.a. Gartenbaukino, MuseumsQuartier, mumok Kino)",
        "district": None,
        "city": "Wien",
        "address": None,
        "price_min": price_min,
        "price_text": price_text,
        "category": "Kurzfilmfestival",
        "description": "Internationales Kurzfilmfestival Vienna Shorts, u.a. im MuseumsQuartier.",
    }
    ea.emit([rec])


if __name__ == "__main__":
    main()
