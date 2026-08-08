# haus_des_meeres

- URL: https://www.haus-des-meeres.at/events-kultur/veranstaltungskalender
- Method: html. No JSON-LD, no XHR endpoint; plain server HTML with cards
  `<div class="col-lg-4 pb-40">` each holding an optional `<a href>` (ticket
  or external CMS link) and a `<p><strong>DD.MM. Category: Title</strong></p>`.
- The page has both an upcoming section and a "Vergangene Veranstaltungen"
  (past events) section in the same markup; we slice between the h2
  "Wissenschaft" intro and the "Vergangene Veranstaltungen" h2 to keep only
  upcoming cards, so no date-based past/future filtering is needed.
- No year in the date text (`DD.MM.`); year starts at today's year and bumps
  by 1 whenever month decreases card-to-card (handles a Dec->Jan wrap).
- No price on this page at all -> price_min/price_text always null (never
  guessed). Category is the verbatim prefix before the colon (e.g.
  "Kulturwelle", "Verein der Freunde", "Verein Wissenschaft & Forschung").
- Site only actually lists ~12 events, running Sep-Dec 2026 (~4 months out)
  even though horizon defaults to 180 days - it just doesn't publish further.
- Breaks if: the "Vergangene Veranstaltungen" heading text changes, or the
  `col-lg-4 pb-40` card markup / `<p><strong>` date-title format changes.
  Re-derive by re-fetching the URL and diffing the card HTML.
