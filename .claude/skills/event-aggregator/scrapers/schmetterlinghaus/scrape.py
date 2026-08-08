import datetime
import re

import ea

SLUG = "schmetterlinghaus"
BASE = "https://www.schmetterlinghaus.at/"
PRICE_URL = BASE + "preise"
VENUE = "Schmetterlinghaus"
ADDRESS = "Palmenhaus Burggarten, Hofburg, 1010 Wien"
DISTRICT = 1010

ADULT_ROW_RE = re.compile(
    r'<td class="cell">Erwachsene</td>\s*'
    r'<td class="cell">([\d,]+)</td>\s*'
    r'<td class="cell">([\d,]+)</td>', re.S)


def adult_price(page):
    m = ADULT_ROW_RE.search(page)
    if not m:
        return None, None
    single, group = m.group(1), m.group(2)
    single_val = float(single.replace(",", "."))
    text = (f"Erwachsene Einzelpreis {single} EUR, "
            f"Gruppenpreis ab 10 Personen {group} EUR")
    return single_val, text


def main():
    home = ea.fetch(BASE, cache="page.html")
    price_page = ea.fetch(PRICE_URL, cache="preise.html")

    price_min, price_text = adult_price(price_page)

    today = datetime.date.today().isoformat()

    if "Schmetterlinghaus" not in home:
        return

    records = [{
        "source": SLUG,
        "source_id": BASE,
        "url": BASE,
        "title": "Schmetterlinghaus",
        "start": today,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": price_min,
        "price_text": price_text,
        "category": None,
        "description": (
            "Tropisches Flugtheater mit rund 500 frei fliegenden "
            "Schmetterlingen im Jugendstil-Palmenhaus im Burggarten, "
            "ganzjährig geöffnet."
        ),
        "status": "scheduled",
        "extra": {"permanent": True},
    }]

    ea.emit(records)


if __name__ == "__main__":
    main()
