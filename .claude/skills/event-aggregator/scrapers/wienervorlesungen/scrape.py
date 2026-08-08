import datetime
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

BASE = "https://vorlesungen.wien.gv.at/"

SECTION_RE = re.compile(
    r"<section\b[^>]*av_textblock_section[^>]*>\s*"
    r"<div class='avia_textblock'\s+itemprop=\"text\"\s*>"
    r"(.*?)</div></section>",
    re.S)

BLOCK_RE = re.compile(
    r"<p>((?:(?!</p>).)*?\d{1,2}\.\s*[A-Za-zÄÖÜäöü]+\.?\s*\d{4}(?:(?!</p>).)*)</p>\s*"
    r"<h2>(.*?)</h2>(.*?)"
    r"<h2><a href=\"([^\"]+)\">mehr lesen</a></h2>",
    re.S)


def clean_title(raw):
    t = ea.text(raw.replace("<br />", " ").replace("<br/>", " "))
    return t


def main():
    page = ea.fetch(BASE, cache="page.html")
    horizon = ea.horizon()
    today = datetime.date.today()

    records = []
    for m in SECTION_RE.finditer(page):
        body = m.group(1)
        bm = BLOCK_RE.search(body)
        if not bm:
            continue
        date_raw, title_raw, middle, url = bm.groups()
        start = ea.de_date(date_raw)
        if not start:
            continue
        d = start[:10]
        try:
            sdate = datetime.date.fromisoformat(d)
        except ValueError:
            continue
        if sdate < today or sdate > horizon:
            continue

        title = clean_title(title_raw)
        if not title:
            continue

        speaker_m = re.search(r"Vortrag von ([^<]+)", middle)
        speaker = ea.text(speaker_m.group(1)) if speaker_m else None

        free_m = re.search(r"\b(frei|gratis|kostenlos|eintritt frei)\b", middle, re.I)
        price_min = 0.0 if free_m else None
        price_text = "Eintritt frei" if free_m else None

        livestream = "MIT LIVESTREAM" in date_raw
        desc = title
        if speaker:
            desc = f"{title} — Vortrag von {speaker}"

        source_id = url.rstrip("/").rsplit("/", 1)[-1] or url

        records.append({
            "source": "wienervorlesungen",
            "source_id": source_id,
            "url": url,
            "title": title,
            "start": start,
            "end": None,
            "venue": "Wiener Rathaus",
            "district": 1010,
            "city": "Wien",
            "address": None,
            "price_min": price_min,
            "price_text": price_text,
            "category": "Vorlesung",
            "description": desc,
            "extra": {"speaker": speaker, "livestream": livestream} if (speaker or livestream) else None,
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
