# eventbrite

- url: https://www.eventbrite.at/d/austria--wien/all-events/ (the curated
  `/d/austria--vienna/events/` discover page only has ~60 shelf events; the
  `all-events` listing has ~880-900, paginated `?page=N`).
- method: html. Each SSR page embeds `window.__SERVER_DATA__ = {...};` with
  `search_data.events.results` (list of event dicts) and
  `search_data.events.pagination.continuation` (null on the last page).
  No auth/cookies needed for these GET pages. The private POST search API
  (`/api/v3/destination/search/`) needs a matching csrftoken cookie +
  Referer and wasn't worth the extra fragility once the SSR pages proved
  sufficient.
- price is NOT present anywhere in the listing JSON, only on detail pages
  (one fetch per event, ~550 requests) — skipped, so price_min/price_text
  are always null (unknown, per spec, not guessed).
- category = the event's `EventbriteCategory` tag display_name, verbatim.
- district parsed from `primary_venue.address.postal_code`.
- object_count/page_count drift slightly between requests (live ranked
  index), so pagination is inherently approximate; scraper stops on empty
  results or a null continuation token, capped at 55 pages as a safety net.
- the site 429s after roughly 45-50 requests within a short window
  (observed while probing manually right after a check.py run) — don't
  chain multiple check.py runs back to back.
- publishes ~13 months out (observed max start ~Sep 2027 from an Aug 2026
  run); horizon_days=180 is just a pagination guide, not a hard filter.
- breaks if: `__SERVER_DATA__` moves/renames, `search_data.events` schema
  changes, or all-events pagination starts requiring the POST API.
