import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

URL = "https://www.kreisky-forum.org/veranstaltungen/"


def main():
    page = ea.fetch(URL)

    i1 = page.find('data-container="events-list" data-view="list"')
    i2 = page.find('data-view="archive"')
    if i1 == -1 or i2 == -1:
        sys.stderr.write("could not locate events-list container\n")
        return ea.emit([])

    seg = page[i1:i2]
    parts = re.split(r'<div id="(\d{4}-\d{2}-\d{2})">', seg)
    # parts[0] is preamble; then alternating (date, block)
    records = []
    for i in range(1, len(parts), 2):
        date_id = parts[i]
        block = parts[i + 1]

        m = re.search(
            r'data-template="title-link"><a href="([^"]+)"[^>]*>(.*?)</a>',
            block, re.S)
        if not m:
            continue
        url = m.group(1).strip()
        title = ea.text(m.group(2))
        if not title:
            continue

        t = re.search(r'<span class="ct-span">(\d{1,2}:\d{2}) Uhr</span>', block)
        start = f"{date_id}T{t.group(1)}" if t else date_id

        schw = re.search(r'data-template="tax-schwerpunkt">(.*?)</div>', block, re.S)
        schwerpunkt = ea.text(schw.group(1)) if schw else None

        persons = re.search(r'data-template="event-persons">(.*?)</div>', block, re.S)
        description = ea.text(persons.group(1)) if persons else None

        fmt = re.search(
            r'data-template="tax-format"><span[^>]*>(.*?)</span>', block, re.S)
        category = ea.text(fmt.group(1)) if fmt else None

        slug = url.rstrip("/").rsplit("/", 1)[-1]

        rec = {
            "source": "kreisky",
            "source_id": slug,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": "Bruno Kreisky Forum",
            "district": 1190,
            "city": "Wien",
            "address": "Armbrustergasse 15, 1190 Wien",
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": description,
            "extra": {"schwerpunkt": schwerpunkt} if schwerpunkt else None,
        }
        records.append(rec)

    ea.emit(records)


if __name__ == "__main__":
    main()
