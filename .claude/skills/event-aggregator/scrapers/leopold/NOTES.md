# leopold

- URL: https://www.leopoldmuseum.org/de/ausstellungen (current shows) + .../vorschau (upcoming). No pagination, no ld+json, no XHR — plain server HTML.
- Method: html. Each `<article class="cfix imgcol exhibition" ... aria-labelledby="article-titleNNN">` holds a link, `<h2 class="title">TITLE</h2>`, a subtitle `<p>`, and a date-range `<p>` in German, e.g. `24.07.2026–10.01.2027`, `24.04.–11.10.2026` (start day/month only, year inferred from end), or `Seit 16.03.2019` (open-ended -> permanent).
- Site currently publishes 3 current + 2 upcoming exhibitions (~7 months out for the furthest). No archive fetched (past-only, not needed).
- No category or price anywhere on these pages (only a generic "Tickets" link) — both always null.
- Venue is always "Leopold Museum" in MuseumsQuartier, district 1070 hardcoded.
- Re-derive: if the `article ... aria-labelledby="article-title` markup or the `–` (en-dash) date separator changes, re-fetch both pages and re-inspect.
