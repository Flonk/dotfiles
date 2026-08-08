import datetime
import json
import sys

import ea

API = "https://app.cineplexx.at/api"
CINEMA_ID = "1009"
CINEMA_NAME = "Actors Studio"
ADDRESS = "Tuchlauben 13, 1010 Wien"
DISTRICT = 1010
SITE_BASE = "https://cineplexx.at"


def get_json(url):
    return json.loads(ea.fetch(url))


def main():
    cutoff = ea.horizon()
    today = datetime.date.today()

    movies = get_json(f"{API}/v1/cinemasweb/{CINEMA_ID}/movies")

    records = []
    for movie in movies:
        movie_id = movie.get("id")
        if not movie_id:
            continue
        title = movie.get("titleCalculated") or movie.get("title") or movie_id
        short_url = movie.get("shortURL")
        url = f"{SITE_BASE}/movie/{short_url}" if short_url else f"{SITE_BASE}/cinemas/{CINEMA_ID}"
        genres = movie.get("genres") or []
        category = ", ".join(genres) if genres else None
        description = ea.text(movie.get("shortSynopsis") or movie.get("synopsis"))

        try:
            days = get_json(f"{API}/v3/moviesweb/{movie_id}/sessions?location=0")
        except Exception as e:
            sys.stderr.write(f"sessions fetch failed for {movie_id}: {e}\n")
            continue

        for day in days:
            for sess in day.get("sessions") or []:
                if sess.get("cinemaId") != CINEMA_ID:
                    continue
                showtime = sess.get("showtime")
                if not showtime:
                    continue
                start = showtime[:16]
                try:
                    start_date = datetime.date(*(int(x) for x in showtime[:10].split("-")))
                except ValueError:
                    continue
                if start_date < today or start_date > cutoff:
                    continue
                sess_id = sess.get("id") or sess.get("sessionId") or f"{movie_id}-{showtime}"
                screen = sess.get("screenName")
                venue = f"{CINEMA_NAME} ({screen})" if screen else CINEMA_NAME
                techs = [t for group in (sess.get("technologies") or []) for t in group if t]
                extra = {"technologies": techs} if techs else None

                rec = {
                    "source": "cineplexx_actors",
                    "source_id": str(sess_id),
                    "url": url,
                    "title": title,
                    "start": start,
                    "end": None,
                    "venue": venue,
                    "district": DISTRICT,
                    "city": "Wien",
                    "address": ADDRESS,
                    "price_min": None,
                    "price_text": None,
                    "category": category,
                    "description": description,
                    "status": "scheduled",
                }
                if extra:
                    rec["extra"] = extra
                records.append(rec)

    ea.emit(records)


if __name__ == "__main__":
    main()
