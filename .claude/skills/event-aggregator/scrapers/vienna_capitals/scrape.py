import re
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import ea

URL = "https://www.vienna-capitals.at/spielplan"
SLUG = "vienna_capitals"

ARTICLE_RE = re.compile(
    r'<article class="game-item-wrapper"[^>]*data-start-at="([^"]*)"'
    r'[^>]*data-game-type="([^"]*)"[^>]*data-month="[^"]*"'
    r'[^>]*data-home-away="([^"]*)"[^>]*>(.*?)</article>', re.S)
AI_RE = re.compile(r'additional-information"[^>]*>([^<]*)<')
LOC_RE = re.compile(r'location-name"[^>]*>([^<]*)<')
DATE_RE = re.compile(r'class="date"[^>]*>([^<]*)<')
TIME_RE = re.compile(r'class="time"[^>]*>\s*([0-9:]+)')
TEAM_RE = re.compile(r'team-name[^"]*"[^>]*>([^<]*)<')


def slugify(s):
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def main():
    page = ea.fetch(URL)
    horizon = ea.horizon()

    records = []
    for m in ARTICLE_RE.finditer(page):
        game_type, home_away, body = m.group(2), m.group(3), m.group(4)

        date_m = DATE_RE.search(body)
        time_m = TIME_RE.search(body)
        if not date_m:
            continue
        start = ea.de_date(date_m.group(1) + (" " + time_m.group(1) if time_m else ""))
        if not start:
            continue

        start_date = start[:10]
        import datetime
        try:
            sd = datetime.date.fromisoformat(start_date)
        except ValueError:
            continue
        if sd > horizon:
            continue

        teams = TEAM_RE.findall(body)
        if len(teams) != 2:
            continue
        home_team, away_team = (ea.text(teams[0]), ea.text(teams[1]))
        if not home_team or not away_team:
            continue

        ai = AI_RE.search(body)
        category = ea.text(ai.group(1)) if ai else None
        loc = LOC_RE.search(body)
        venue = ea.text(loc.group(1)) if loc else None

        title = f"{home_team} vs {away_team}"
        source_id = f"{start_date}-{slugify(home_team)}-vs-{slugify(away_team)}"

        records.append({
            "source": SLUG,
            "source_id": source_id,
            "url": URL,
            "title": title,
            "start": start,
            "end": None,
            "venue": venue,
            "district": ea.district(venue),
            "city": "Wien",
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": None,
            "extra": {
                "home_away": home_away,
                "game_type": game_type,
                "home_team": home_team,
                "away_team": away_team,
            },
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
