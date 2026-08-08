# cineplexx_urania

- meta.json url (cineplexx.at) is a JS-shell SPA; its API (app.cineplexx.at,
  cinemaId 1025) does return real sessions, but the movie ids referenced
  (e.g. HO00000496) 404 on /api/v1/movies/{id} — Urania's arthouse titles
  aren't in Cineplexx's shared movie DB, so no title could be joined.
- The cinema now operates as "URANIA CEENEMA" with its own server-rendered
  site: https://ceenema.eu/spielplan — a single GET returns every published
  day (`id="elem-<weekday>. <dd>.<mm>"` row per day, `card v4` divs with
  title/country/runtime/description/showtime) with no JS needed. Used that
  as the actual source (method: html).
- Dates on the page have no year; scrape.py infers it from today's date
  (rolls to next year only if the parsed day is >2 days in the past).
- Site currently publishes ~24 days ahead (one page, no "load more" link
  followed — button is JS/AJAX driven, not worth chasing for ~3 extra weeks).
  horizon_days set to 24 to match what's actually there.
- category is never labelled per-film on the page (only global nav filter
  tags exist) → always null. Price is never published anywhere → always null.
- breaks if: ceenema.eu changes the `card v4` / `select_buttons
  menu-card-inner-bottom` / `id="elem-..."` markup, or moves off this
  static-HTML template to a JS-rendered one.
- re-derive: view-source https://ceenema.eu/spielplan, search for
  `id="elem-`.
