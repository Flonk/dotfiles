# stadtkinowien

- url: https://www.stadtkinowien.at/ — WordPress site, no ld+json, no API.
- method: html. Programme lives at `/programm/dat/YYYYMMDD/`, which renders
  a rolling 3-day window starting at the requested date (three
  `<div class="film-column">`, empty ones with no content just render as a
  bare `<div>`). Step the request date by 3 to tile the whole horizon with
  no gaps/overlap.
- year is never printed (h3 only has weekday + "21. August"), so start
  dates are computed from `requested_date + column_offset`, not parsed
  from text — avoids year ambiguity entirely.
- each `<article class="film">` = one showtime: time, `show_id` (used as
  `source_id`) in the ticket link, title+detail URL, director + origin/year
  line, description, optional bold notice (e.g. "In Anwesenheit ...").
  "Geschlossene Veranstaltung" (private closed screenings, no public info)
  is skipped.
- price never published, not even on the JS ticket-booking app
  (tickets.stadtkinowien.at) — `price_min`/`price_text` always null.
  Category/genre likewise never published — always null.
- single venue: Stadtkino im Künstlerhaus, Akademiestraße 13, 1010 Wien
  (hardcoded; the Siebensterngasse address in the footer is the office,
  not the cinema).
- scraped during Sommerpause (23.7.–19.8.); program otherwise published
  ~90 days out (into November).
- breaks if: `film-column`/`article class="film"` markup changes, or the
  `/programm/dat/` URL scheme changes.
- re-derive: view-source `/programm/dat/<today YYYYMMDD>/`.
