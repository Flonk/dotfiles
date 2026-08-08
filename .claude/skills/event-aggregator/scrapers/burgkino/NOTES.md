# burgkino

- url: https://www.burgkino.at/ — Drupal 8/9 site, no ld+json, no API.
- method: html. Gather movie slugs from `/`, `/showtimes/this-week`,
  `/showtimes/next-week`, `/coming-soon` (regex `/movie/([a-z0-9-]+)`), then
  fetch each `/movie/<slug>` page: parse its showtimes `<table>` rows
  (date, time, room, price, `show_id` in the ticket link) via `ROW_RE`, plus
  `<h1><span>` title and the Genre field for `category`.
- date/time: table's second `<time>` column text ("17:30") is the reliable
  local Vienna wall-clock value — do NOT trust its `datetime="...Z"`
  attribute (it's mislabeled, holds the local value, not real UTC); the
  first column's `datetime` attribute *is* real UTC. Parsed from the
  human-readable text instead to sidestep the ambiguity.
- movies with no showtime rows yet (future releases) fall back to a single
  record using `/coming-soon`'s "Starting" planned date (date-only, no
  price — genuinely unknown, not guessed).
- real bookable showtimes only extend ~1 week (this-week+next-week);
  beyond that a few premiere/preview screenings pop up on specific future
  Thursdays (checked via `/showtimes/custom?dateselect=YYYY-MM-DD`), and
  `/coming-soon` gives planned dates out several months for other titles.
  horizon_days=90 keeps most of the placeholder records, drops far 2027
  releases.
- price: €10.50 standard, varies by day/movie (Mon €8, some €12.50); "€
  8.00" style via `ea.price`.
- breaks if: the views table markup (`views-field-field-startdatetime`
  class / `show_id=` query param) changes, or `/coming-soon`'s "Starting"
  label wording changes.
- re-derive: view-source any `/movie/<slug>` page, find the showtimes
  `<table>`.
