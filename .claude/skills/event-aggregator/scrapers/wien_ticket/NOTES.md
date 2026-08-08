# wien_ticket

- url: https://www.wien-ticket.at/ — robots.txt only disallows /shop, /shopf, cticketkauf (checkout flows); listing pages are open.
- method: html. Category catalog pages (`/de/{konzerte,klassik,kultur,musicals-shows,sport,freizeit}/catalog`,
  paginated via `/catalog/from{N}`, 20/page) render each event as `<li class="event-list-item"
  data-tracking="<base64 GA4 json>">`. The base64 blob decodes to clean fields: item_id, item_name,
  spielstaette (venue), item_category, veranstaltungsdatum/-zeit (start date/time). No per-detail-page
  fetches needed. End date, when shown, comes from the visible "Fr, 14.08. - So, 30.08.2026" text next
  to the item (second date parsed out); many are single-day so end is left null.
- Standing/open tickets (city tours, museum day-passes) carry a stale/placeholder veranstaltungsdatum
  (sometimes years in the past, or empty). Detected via parsed start < today and emitted with
  extra.permanent=true, start=today, end=null per the no-fabrication rule.
- Site publishes far ahead — sample events reach into 2028 depending on category. Sorted ascending by
  start within each category, so pagination stops once a page's start dates cross ea.horizon() (with a
  180-day default horizon that gathered 667 records across ~6 categories in ~90s).
- Breaks if: the `event-list-item` / `data-tracking` markup changes, or the GA4 tracking payload shape
  changes (`ecommerce.items[0]`). Re-derive by curling any `/de/{category}/catalog` page and inspecting
  one `<li>` block.
- end: added 2026-08-08. Each detail page has schema.org `Event` JSON-LD with a real
  per-event `endDate` (1.5h-3h after start, varies by show - not a fixed offset, confirmed
  by sampling). `enrich_ends()` fetches every unique event URL once via a 10-worker
  ThreadPoolExecutor after the listing pass and matches by `startDate` (a detail page can
  list several JSON-LD blocks, one per upcoming date of that show). Adds ~2-2.5min to the
  run (listing alone is ~90s; full run with enrichment is ~3-3.5min for ~650 events, still
  well under check.py's 300s budget). The site occasionally emits a garbage endDate sentinel
  (`-001-11-30T00:00:00+01:05`, seen on a handful of events) - rejected by requiring a valid
  4-digit-year ISO timestamp and end >= start; those records correctly keep end=null rather
  than trusting it. Result: 98% end fill on timed records (639/652 in the sample run).
