# zoovienna

- url: https://www.zoovienna.at/termine/ (calendar, `?year=&month=&t=<filter>`)
- method: html. Monthly calendar (`event-item__header` / `event-item__date`) discovers
  event slugs across ~7 months up to the horizon. Each event's detail page has a
  "Nächste Termine" (`next-event-dates`) list with the actual bookable/specific
  occurrence dates (sometimes with time or a time range, occasionally a note like
  "ausgebucht" or a sub-topic e.g. "Reptilien & Amphibien") — one schema record per
  listed date, per the spec.
- category comes from the site's own filter checkboxes (`name="t"` + `<label>`); found
  by re-fetching the event's month with each filter id until the event's href shows up.
- price parsed from the "Kosten:" line in `editable-content` via `ea.price()`
  (handles "kostenlos" / € amounts); left null when the text only says "nur
  Tiergarten-Eintritt" (zoo admission required, no stated event price).
- Site only publishes a small set of ticketed/special events (Safari Dinner,
  Polarnacht, a workshop, kids advent tours, Artenschutztage, a Christmas day
  program) — daily animal feedings and general zoo opening are intentionally not
  modelled as occurrences. Concrete dates are usually only published a few months
  ahead (site's own "Nächste Termine"), so record count stays small — this is real,
  not a scraper bug.
- Breaks if: `event-item__header`/`event-item__date` classes change, or the
  `next-event-dates` block / date format ("Fr, 14.8.2026[, HH:MM[ bis HH:MM] Uhr][:
  note]") changes. Re-derive by refetching `/termine/` and a detail page and
  re-checking the regexes in scrape.py.
