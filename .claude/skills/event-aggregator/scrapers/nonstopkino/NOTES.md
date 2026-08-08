# nonstopkino

- url: https://nonstopkino.at/events/ — member preview screenings for the "nonstop"
  cinema subscription (not a regular cinema program).
- method: html. Listing page renders all ~62 events (past+future) in one page, no
  pagination. Each `<article class="event" id="<slug>" data-date="YYYYMMDD">` gives
  id/date/title/href/location/highlight-tag; fetch each `/events/<slug>/` detail page
  for the exact "Datum" value (adds time, colon format only, e.g. "19:30") and location.
- multi-date events: "Lord of The Rings Event" lists "5., 11., und 19.09.2026" — parsed
  into 3 separate occurrences via `DAY_LIST_RE`; everything else is a single date.
- Graz events (Geidorf Kunstkino, KIZ RoyalKino, Schubert Kino) are filtered out — this
  aggregator is Vienna-only; detected via "Graz" in the listing page's location text.
- price: always unknown — access is via subscription, not per-event ticket price, so
  `price_min` stays null; the site's own label ("Nur für Mitglieder", "Ticketverlosung",
  "Anmeldung über Cinema Next") goes into `category` instead.
- horizon: site currently only lists events out to ~Nov 2026 (scraped Aug 2026, so
  ~3.5 months ahead); horizon_days=90 already captures nearly all of it.
- breaks if: the `<article class="event" id="…" data-date="…">` markup changes, or the
  detail page's `<p class="date"><span class="value">` structure changes.
- re-derive: view-source https://nonstopkino.at/events/ and any /events/<slug>/ page.
