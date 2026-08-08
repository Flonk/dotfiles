# volxkino

- url: https://www.volxkino.at/ — Wix site, homepage has no server-rendered
  schedule text; instead a `<script id="wix-warmup-data">` tag holds the full
  Wix Events widget payload as JSON (SSR warmup data for hydration).
- method: html (really "embedded JSON blob"). Parse warmup script, walk
  `appsWarmupData.*.*.events.events` for a list of event objects. Each has
  `scheduling.config.startDate/endDate` (UTC ISO), `location.address` and
  `location.name`, `title`, `slug`, `description`, `id`.
- Times converted UTC -> Europe/Vienna with zoneinfo. `end` = the site's own
  endDate (same-evening screening end, not a multi-day run).
- No price anywhere (RSVP-only Wix ticketing, no fee field) -> price always
  null. No per-event category field on the site -> category always null.
- District from the free-text `location.address` (regex for postcode); the
  structured `fullAddress.postalCode` occasionally disagrees by a district
  or two (bad data entry by the organiser) — address text wins since that's
  what's displayed publicly.
- Horizon: as of scrape time site lists 15 screenings, all in Aug 2026
  (summer open-air season, ends ~31 Aug). Whole season fits well within
  EA_HORIZON_DAYS; no pagination needed.
- Breaks if: Wix drops/renames the `wix-warmup-data` script id, or nests
  the events app under a different appDefId/widget key.
