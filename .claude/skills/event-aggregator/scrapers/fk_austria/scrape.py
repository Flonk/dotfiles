import datetime
import re

import ea

URL = "https://www.fk-austria.at/teams/profis/spielplan"
SOURCE = "fk_austria"

WD = {"Mo.": None, "Di.": None, "Mi.": None, "Do.": None,
      "Fr.": None, "Sa.": None, "So.": None}

DATE_RE = re.compile(
    r"[A-Za-zÄÖÜäöü]{2}\.\s*(\d{2})\.(\d{2})\.(\d{4})")
TIME_RE = re.compile(r"(\d{2}):(\d{2})")

ROW_SPLIT = re.compile(r'<div class="game-schedule-row[^"]*">')
DATE_BLOCK_RE = re.compile(
    r'match-date w-1/5.*?font-gothic-regular">([^<]+)</p>\s*'
    r'<p class="text-base text-textfields-300 font-gothic-regular">([^<]+)</p>',
    re.S)
COMP_RE = re.compile(
    r'Symbole/[^"]+\.png" class="w-6 md:w-7"[^>]*alt="([^"]*)"')
NAMES_RE = re.compile(
    r'font-gothic-regular hidden md:block">([^<]+)</p>')
GOALS_BLOCK_RE = re.compile(r'goals w-1/5.*?</div>', re.S)
GOALS_RE = re.compile(r'font-gothic-bold">\s*([\-0-9]+)\s*</p>')

VENUE_HOME = "Generali-Arena"
DISTRICT_HOME = 1100


def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def parse_rows(page):
    parts = ROW_SPLIT.split(page)[1:]
    out = []
    for p in parts:
        m_date = DATE_BLOCK_RE.search(p)
        m_comp = COMP_RE.search(p)
        names = NAMES_RE.findall(p)
        if not m_date or len(names) != 2:
            continue
        date_s, time_s = m_date.groups()
        md = DATE_RE.search(date_s + " " + date_s)
        m2 = re.search(r"(\d{2})\.(\d{2})\.(\d{4})", date_s)
        if not m2:
            continue
        day, mon, year = m2.groups()
        start = f"{year}-{mon}-{day}"
        mt = TIME_RE.search(time_s)
        has_real_time = bool(mt) and time_s.strip() != "01:00"
        if has_real_time:
            start += f"T{mt.group(1)}:{mt.group(2)}"

        goals_blocks = GOALS_BLOCK_RE.findall(p)
        played = False
        if goals_blocks:
            g = GOALS_RE.findall(goals_blocks[0])
            played = len(g) == 2 and all(v != "-" for v in g)

        comp = (m_comp.group(1) if m_comp else "").replace(" white", "").strip()
        category = comp if comp and comp != "Ic ball" else None

        home, away = names[0].strip(), names[1].strip()
        out.append({
            "start": start,
            "home": home,
            "away": away,
            "category": category,
            "played": played,
        })
    return out


def main():
    page = ea.fetch(URL)
    rows = parse_rows(page)
    today = datetime.date.today().isoformat()

    records = []
    for r in rows:
        if r["start"][:10] < today:
            continue
        home, away = r["home"], r["away"]
        title = f"{home} vs {away}"
        is_home = home == "Austria Wien"
        sid = f"{r['start'][:10]}-{slugify(home)}-{slugify(away)}"
        records.append({
            "source": SOURCE,
            "source_id": sid,
            "url": URL,
            "title": title,
            "start": r["start"],
            "end": None,
            "venue": VENUE_HOME if is_home else None,
            "district": DISTRICT_HOME if is_home else None,
            "city": "Wien",
            "category": r["category"],
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
