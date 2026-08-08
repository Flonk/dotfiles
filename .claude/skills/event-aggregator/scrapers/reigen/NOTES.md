# reigen

- url: https://www.reigen.at/ — single venue (blues/jazz/rock club, Hadikgasse
  62, 1140 Wien). Not using homepage HTML; it only carries generic
  WebPage/Organization JSON-LD, no Event data.
- method: api. Site runs "The Events Calendar" (tribe) plugin, exposing
  `/wp-json/tribe/events/v1/events?per_page=50&page=N`. No auth, no key.
  73 total events across 2 pages as of 2026-08-08.
- Site publishes very far ahead (through Nov 2027 seen), so no
  EA_HORIZON_DAYS pagination cutoff was implemented — just fetch all pages
  (capped at 10 as a safety valve). Note there was a real gap: nothing
  listed between today (2026-08-08) and 2026-09-11 (summer break), confirmed
  by re-querying with an explicit start_date — not a scraper bug.
- `categories`/`tags` are empty on every event on this install -> category
  is always null (verbatim from source = nothing to report).
- `cost` is either "" (unknown/not yet priced, price_min null) or a range
  like "22€ – 25€" (price_min = low end via ea.price). Never seen "frei".
- description = HTML body text via ea.text(), truncated to ~500 chars.
- single date per event (start_date == end_date day always in sample) so
  `end` is left null.
- breaks if: the tribe REST endpoint is removed/renamed, or the site drops
  The Events Calendar plugin. Re-derive by re-checking
  /wp-json/tribe/events/v1/ discovery route linked from the homepage.
