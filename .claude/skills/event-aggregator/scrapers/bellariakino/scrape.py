import datetime
import zoneinfo
from concurrent.futures import ThreadPoolExecutor

import ea

API = "https://api.cineamo.com/showings"
MOVIE_API = "https://api.cineamo.com/movies/{}"
TMDB_IMG = "https://image.tmdb.org/t/p/w500"
CINEMA_ID = "3000"
VENUE = "Bellaria Kino"
ADDRESS = "Museumstraße 3, 1070 Wien"
DISTRICT = 1070
VIENNA = zoneinfo.ZoneInfo("Europe/Vienna")


def fetch_movie(movie_id):
    import json
    for attempt in range(3):
        try:
            raw = ea.fetch(MOVIE_API.format(movie_id), timeout=20)
            d = json.loads(raw)
            image = f"{TMDB_IMG}{d['posterPath']}" if d.get("posterPath") else None
            runtime = d.get("runtime")
            return movie_id, image, (int(runtime) if runtime else None)
        except Exception:
            continue
    return movie_id, None, None


def local_dt(iso_utc):
    if not iso_utc:
        return None
    dt = datetime.datetime.strptime(iso_utc, "%Y-%m-%dT%H:%M:%SZ")
    dt = dt.replace(tzinfo=datetime.timezone.utc).astimezone(VIENNA)
    return dt.strftime("%Y-%m-%dT%H:%M")


def fetch_all():
    import json
    items = []
    page = 1
    while True:
        url = f"{API}?cinemaIds%5B0%5D={CINEMA_ID}&perPage=100&page={page}"
        raw = ea.fetch(url)
        data = json.loads(raw)
        batch = data.get("_embedded", {}).get("showings", [])
        items.extend(batch)
        if page >= data.get("_page_count", page):
            break
        page += 1
    return items


def lang_desc(it):
    parts = []
    lang = it.get("language")
    if lang:
        parts.append(f"OV: {lang}")
    if it.get("isDubbed") and it.get("dubbedLanguage"):
        parts.append(f"synchronisiert: {it['dubbedLanguage']}")
    if it.get("isSubtitled") and it.get("subtitledLanguage"):
        parts.append(f"UT: {it['subtitledLanguage']}")
    return ", ".join(parts) if parts else None


def build(it):
    start = local_dt(it.get("startDatetime"))
    if not start:
        return None
    title = ea.text(it.get("name"))
    if not title:
        return None
    content = (it.get("_embedded") or {}).get("content") or {}
    content_id = it.get("contentId")
    showing_id = it.get("id")
    url = f"https://www.bellariakino.at/de/programm/{content_id}/{showing_id}"
    desc_parts = [p for p in (ea.text(content.get("description")), lang_desc(it)) if p]
    return {
        "source": "bellariakino",
        "source_id": str(showing_id),
        "url": url,
        "title": title,
        "start": start,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": content.get("category"),
        "description": " / ".join(desc_parts) if desc_parts else None,
        "image": content.get("posterImageUrl") or content.get("backdropImageUrl"),
        "status": "scheduled" if it.get("state") != "cancelled" else "cancelled",
        "movie_id": it.get("movieId"),
    }


def main():
    today = datetime.date.today()
    cutoff = ea.horizon()
    items = fetch_all()
    records = []
    for it in items:
        rec = build(it)
        if not rec:
            continue
        d = datetime.date.fromisoformat(rec["start"][:10])
        if d < today or d > cutoff:
            continue
        records.append(rec)

    movie_ids = sorted({r["movie_id"] for r in records if r.get("movie_id")})
    movies = {}
    if movie_ids:
        with ThreadPoolExecutor(max_workers=8) as ex:
            for mid, image, runtime in ex.map(fetch_movie, movie_ids):
                movies[mid] = (image, runtime)
    for r in records:
        mid = r.pop("movie_id", None)
        image, runtime = movies.get(mid, (None, None))
        if not r.get("image") and image:
            r["image"] = image
        if runtime:
            r["extra"] = {"duration_min": runtime}

    ea.emit(records)


if __name__ == "__main__":
    main()
