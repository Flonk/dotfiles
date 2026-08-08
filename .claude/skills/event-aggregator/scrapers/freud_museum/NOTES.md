# freud_museum

- URL: https://www.freud-museum.at/ (Contao CMS). Base site redirects `/`
  to `/en/`; scraper uses the German pages directly.
- Method: html. Three server-rendered pages, no JSON-LD Event data and no
  XHR/API:
  - `de/ausstellungen-programm/programm` — talks/conferences (`.mod_eventlist
    .event` blocks), only ~3 upcoming at a time.
  - `de/fuehrungstermine` — recurring public/special guided tours, same
    `.event` block markup, ~20 listed, extending only ~3.5 months out (site
    just doesn't publish further, even though horizon is 180d).
  - `de/ausstellungen-programm` — the 5 current exhibitions as
    `.ce_rsce_teaser` tiles; dates (if any) are free text in the teaser `<p>`,
    parsed for "DD. Month YYYY - DD. Month YYYY" or "ab DD. Month YYYY".
- 3 of 5 exhibitions have no end date on the site → `end: null`,
  `extra.permanent: true`. 2 of those also have no start date at all →
  `start` is set to the scrape date (never fabricate an end, but a "running
  as of today" start for a genuinely dateless permanent exhibit is the least
  bad option).
- No price info anywhere on the site → `price_min`/`price_text` always null.
  No real per-event category field exists → `category` always null.
- Breaks if: Contao markup class names change (`event event--teaser`,
  `ce_rsce_teaser`, `event__date`, `teaser__subheadline`), or the site moves
  events off these three URLs. Re-derive by viewing source of the three
  pages above.
