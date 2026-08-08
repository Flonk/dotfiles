# cineplexx_actors

- url: https://cineplexx.at/cinemas/Actors-Studio — pure React SPA, page.html has no data.
- method: api. Data comes from app.cineplexx.at (no auth needed):
  - `/api/v1/cinemasweb/1009/movies` — movies currently listed at Actors Studio (cinema id 1009,
    found via `/api/v1/cinemas`). Note the missing slash is real: baseUrl `"/cinemas"` + `"web/"`.
  - `/api/v3/moviesweb/{movieId}/sessions?location=0` — all Vienna sessions for that movie;
    filter to `sess["cinemaId"] == "1009"`. `location=0` is the Wien region id from
    `/api/v1/locations`, not a cinema id (cinema id there returns 400 "Ungültiger Standort").
- Site only actually publishes showtimes ~5-6 days out (checked 2026-08-08: last date was
  2026-08-13), so EA_HORIZON_DAYS is basically irrelevant here — cutoff just never gets hit.
- No ticket price is exposed anywhere in these endpoints, so price_min/price_text are always null.
- Breaks if: cinema id 1009 changes, or the API moves off app.cineplexx.at, or the
  `web/{id}/movies` / `web/{id}/sessions` route shapes change (they're clearly quirky/legacy-ish).
- Re-derive: fetch `/api/v1/cinemas`, find id for cinemaUrlName "Actors-Studio".
