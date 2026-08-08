# vienna_events

- url: https://www.vienna-events.com/en/events
- method: jsonld. Each listing page embeds one `application/ld+json` Event
  block per card, in the same order as the card `<a href>` links. Paginate
  with `?page=N`; page 1 has no query. Card count per page is 20; total is
  shown as `<h2>N Events found</h2>` (canary).
- Site publishes far ahead: at build time page 8 (last page, ~156 events
  total) still had events into April 2027, so pagination is effectively
  bounded by the site itself, not by us — we just stop once a page's max
  date passes `ea.horizon()`.
- No price info anywhere (list or ld+json) -> price_min/price_text always
  null.
- `location.address` in the ld+json is buggy: several distinct venues share
  one bogus street string (e.g. Porgy & Bess and Viper Room both show "38
  Landstrasser Hauptstrasse"). Not trusted; address/district left null.
- `startDate`/`endDate` have no real time-of-day (always ~00:00 UTC-ish,
  sometimes 02:00 for no discernible reason) -> only the date is kept,
  start/end are date-only.
- Detail link hrefs contain a site bug, double slash `/en//events/...`;
  normalized to single slash. `source_id` is the trailing `-eNNNN` in the
  slug.
- Re-derive: refetch page 1, diff the Tailwind class names / JSON-LD schema
  if parsing breaks.
