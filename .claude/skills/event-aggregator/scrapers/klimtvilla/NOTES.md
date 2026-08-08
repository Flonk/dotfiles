# klimtvilla

- URL: https://www.klimtvilla.at/veranstaltungen/ (Modern Events Calendar / MEC
  plugin, list skin, shortcode id 368284).
- Method: api. The first page of events is server-rendered `<script
  type="application/ld+json">` Event blocks. Further pages come from POSTing
  to `/wp-admin/admin-ajax.php` with `action=mec_list_load_more`, chaining
  `mec_start_date`/`mec_offset`/`current_month_divider` from each JSON
  response, plus the `atts` querystring scraped out of the page's inline
  `mecListView({...})` call. Stop when a response has `count: 0` (its
  `has_more_event` flag stays 1 forever and can't be trusted).
- Category isn't in the JSON-LD, so each event's detail page is fetched once
  to pull the verbatim category from `<dd class="mec-events-event-categories">`
  (only ~15-20 events total — cheap).
- Site currently only has real dates through 20 Dec 2026 (4 Adventzauber
  Sundays) even though EA_HORIZON_DAYS defaults to 180 (~early Feb 2027) —
  it just publishes less far ahead than the horizon allows; not a bug.
- Past occurrences (e.g. today's date already gone) appear mixed into the
  first ajax-free batch, so records with start date < today are dropped.
- Breaks if: MEC is swapped out, the `mecListView(` inline settings block
  disappears/renamed, or the ajax action/param names change (re-derive from
  a fresh page fetch + the plugin's `assets/js/frontend.js`, search for
  `mec_list_load_more`).
