# konzerthaus

- url: https://www.konzerthaus.at/de/programm-und-karten — SSR Nuxt page whose
  embedded `window.__NUXT__` payload is a hand-rolled var-deduped JS object
  literal (not real JSON, not evaluable with stdlib). Ignored it.
- method: api. The frontend backs onto a plain REST endpoint:
  `https://konzerthaus.at/api/events/?date=YYYY-MM-DD&page_size=100&page=N`
  (date param is required — server 400s without it; it seems to act as the
  lower bound / "from" date, results are sorted ascending by date_start).
  Paginate via `page` until `date_start` on a page exceeds `ea.horizon()`,
  or `next` is null.
- Sees ~662 total upcoming occurrences at fetch time, stretching to
  ~Sept 2027 (>1 year out). We stop early at the horizon so actual record
  count depends on `EA_HORIZON_DAYS` (163 at the default 90-day horizon
  used in meta.json's schedule).
- venue: `room.venue.name` is either "Wiener Konzerthaus" (main house,
  hardcoded address Lothringerstraße 20, 1030 Wien) or literally
  "externe Veranstaltungsstätten" for off-site events, in which case
  `room.name` already names the real venue (e.g. "Musikverein,
  Brahms-Saal") and no address/district is known.
- category = comma-joined `genres[].name` (empty for ~40% of events,
  esp. tours/backstage — left null, not guessed).
- price_min = min of `prices[].price` (all numeric EUR strings observed;
  no explicit "free" events seen, so price_min 0 never emitted here).
  ~14% of events have no prices array at all -> null.
- status: API `status` field has values None/future/sale/open/soldout/rest/
  postponed — only "postponed" maps to the schema enum, everything else
  -> "scheduled" (no "cancelled" value observed in ~660 records sampled).
- breaks if: `/api/events/` starts requiring auth/CORS headers, drops the
  `date` query param requirement, or the URL slug pattern
  `/de/programm-und-karten/<slug.de>/<id>` changes.
- re-derive: curl the listing page, look for `window.__NUXT__` links of
  form `/de/programm-und-karten/<slug>/<id>`, then just try
  `/api/events/?date=<today>` directly — no auth needed.
