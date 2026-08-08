import datetime
import re

import ea

BASE = "https://www.bestattungsmuseum.at"
TOUREN_URL = f"{BASE}/fuehrungen"
SHOP_TICKETS_URL = "https://shop.bestattungsmuseum.at/kategorie/tickets/"
SCHEINTOT_TICKET_URL = "https://shop.bestattungsmuseum.at/tickets/Besuch-im-Museum-Vortrag-Scheintot-die-Angst-lebendig-begraben-zu-werden"

VENUE = "Bestattungsmuseum Wien"
ADDRESS = "Simmeringer Hauptstrasse 234, 1110 Wien"
DISTRICT = 1110

today = datetime.date.today()
cutoff = ea.horizon()


def future_dates_from_page(html):
    dates = []
    for m in re.finditer(r'data-option-date="(\d{1,2}\.\d{1,2}\.\d{4})"', html):
        d = ea.de_date(m.group(1))
        if not d:
            continue
        dd = datetime.date.fromisoformat(d)
        if today <= dd <= cutoff:
            dates.append(d)
    return sorted(set(dates))


def main():
    page = ea.fetch(TOUREN_URL)

    m = re.search(
        r"<li[^>]*>(\d+)\s*Euro pro Person regulär</li>\s*"
        r"<li[^>]*>(\d+)\s*Euro pro Person ermäßigt",
        page)
    fuehrung_price_min = None
    fuehrung_price_text = None
    if m:
        fuehrung_price_min = float(min(int(m.group(1)), int(m.group(2))))
        fuehrung_price_text = f"{m.group(1)} Euro regulär / {m.group(2)} Euro ermäßigt"

    records = []

    fp = ""
    try:
        cat = ea.fetch(SHOP_TICKETS_URL)
        cm = re.search(
            r'href="(https://shop\.bestattungsmuseum\.at/tickets/Ticket-fuer-eine-Fuehrung[^"]*)"',
            cat)
        if cm:
            fp = ea.fetch(cm.group(1))
    except Exception:
        fp = ""
    for d in future_dates_from_page(fp):
        records.append({
            "source": "bestattungsmuseum",
            "source_id": f"fuehrung-{d}",
            "url": TOUREN_URL,
            "title": "Öffentliche Führung im Bestattungsmuseum Wien",
            "start": d,
            "end": None,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": fuehrung_price_min,
            "price_text": fuehrung_price_text,
            "category": "Öffentliche Führungen",
            "description": ("Öffentliche Führung durch das Bestattungsmuseum Wien mit "
                             "Guides zur Wiener Bestattungskultur."),
        })

    sm = re.search(r"Termine:\s*([0-9.,\s]+)</li>", page)
    scheintot_dates = []
    if sm:
        for tok in sm.group(1).split(","):
            tok = tok.strip()
            if not tok:
                continue
            d = ea.de_date(tok, default_year=today.year)
            if not d:
                continue
            dd = datetime.date.fromisoformat(d)
            if dd < today:
                d2 = ea.de_date(tok, default_year=today.year + 1)
                if d2:
                    dd2 = datetime.date.fromisoformat(d2)
                    if today <= dd2 <= cutoff:
                        scheintot_dates.append(d2)
                continue
            if today <= dd <= cutoff:
                scheintot_dates.append(d)

    try:
        sp = ea.fetch(SCHEINTOT_TICKET_URL)
    except Exception:
        sp = ""
    scheintot_price_min, scheintot_price_text = (None, None)
    pm = re.search(r'itemprop="price"\s*\n?\s*content="([\d.]+)"', sp)
    if pm:
        scheintot_price_min = float(pm.group(1))
        scheintot_price_text = f"{pm.group(1)} Euro (Kombiticket Museum & Vortrag)"

    for d in sorted(set(scheintot_dates)):
        records.append({
            "source": "bestattungsmuseum",
            "source_id": f"scheintot-{d}",
            "url": SCHEINTOT_TICKET_URL,
            "title": "Sondervortrag: „Scheintot – die Angst lebendig begraben zu werden“",
            "start": d,
            "end": None,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": scheintot_price_min,
            "price_text": scheintot_price_text,
            "category": "Sondervortrag",
            "description": ("Kombiticket: Museumsbesuch & Vortrag mit Prof. Dr. med. univ. "
                             "Roland Sedivy und Cornelia Fassl über den Scheintod und die "
                             "historische Angst, lebendig begraben zu werden."),
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
