# tuwien

- url: https://www.tuwien.at/en/tu-wien/news/events
- method: html (server-rendered TYPO3 list, no JS needed)
- Paginated at /en/tu-wien/news/events/page/N, 10 events/page, sorted ascending by
  date. Total page count parsed from "Page X of N" in the pagination nav.
- Each `<article class="wpListItem" aria-labelledby="event-ID">` holds title/link,
  a date block (`wpDate one` = single day w/ optional start-end time, `wpDate two`
  = multi-day range with a "DD Month YYYY until DD Month YYYY" visually-hidden
  string), a type tag (-> category verbatim), and a location string (-> venue,
  district parsed via postal code if present).
- Site publishes events far ahead (into 2027 seen on page 4); we stop paginating
  once a page's earliest date passes EA_HORIZON_DAYS, so real depth exceeds
  the configured horizon.
- No price info on the list page at all -> price_min/price_text always null.
- Breaks if TYPO3 template changes class names (wpListItem/wpDate/wpTypeTag/
  wpLocation) or the pagination text format ("Page X of Y").
