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
