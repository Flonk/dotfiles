# votivkino

- url: https://www.votivkino.at/. method: html (three server-rendered pages,
  no JSON/JS-only shell).
- `/programm/tag/?date=YYYYMMDD` gives that day's full showtime cards
  (`id="film_card_..."` blocks with nested `<li id="stuid_...">` showtime
  items). Scraper iterates today..min(horizon, +21d); real dense daily
  listings only actually exist for ~1-2 weeks ahead, later days return an
  empty list (still 200 OK).
- `/specials/` lists further-out one-off "special strand" screenings
  (Sleazy Sunday, Game: On!, watch & talk, ...) with real dates, seen up to
  ~2 months out; scraped once, dates before today or past horizon dropped.
- `/vorschau/` lists announced-but-not-yet-scheduled premieres as
  `<time datetime="YYYY-MM-DD" class="date fCoign">Ab DD.MM.</time>`; used
  only as a date-only fallback record for films not already captured with a
  real showtime, `extra.planned_start: true`.
- Showtimes for "Bellaria Kino" (`showtime_kino_bellaria` class) appear
  interleaved in the same markup as Votiv Kino / Kino De France but are
  CSS-hidden for logged-out visitors; skipped on purpose (bellariakino has
  its own scraper slug).
- No genre/category field anywhere on the site; `category` is whatever
  marketing strand label the card carries (often just "Primetime") or null.
  No per-showtime price is published; price_min/price_text always null.
- Breaks if: the `film_card_`/`stuid_` id prefixes, the `card-showtimes` /
  `showtime_kino_*` classes, or the `/programm/tag/?date=` query param
  change.
