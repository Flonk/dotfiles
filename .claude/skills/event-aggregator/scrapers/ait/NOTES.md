# ait

- url: https://www.ait.ac.at/news-events/events
- method: api. The events tab renders no items server-side except a
  "load more" button; the widget calls
  `/index.php?id=2580&tx_aitnewsfeatures_newsapi[amount]=...&[show]=events&
  [searchDateFrom]=...&[searchDateTo]=...` (found in the compressed
  script.js bundle) and returns raw teaser HTML fragments with
  `data-date` (unix ts of the event's END date) and `data-uid`.
- scrape.py: hits that endpoint with a wide date range, parses the day/
  month teaser + timestamp into start/end, then fetches each detail page
  (`/news-events/single-view?tx_ttnews[tt_news]=<uid>`) to pull a precise
  h1 title, an optional start time and venue out of free-text
  "Datum:"/"Ort:"/"Veranstaltungsort" phrasing (format varies per event,
  not fully structured).
- Only 3 upcoming events at build time — genuine, not a bug (amount=100
  still returns 3); this filtered page is thin by nature.
- Publishes out to ~7 weeks ahead at build time (through late Sep from an
  early-Aug run); re-check by widening searchDateTo, results are already
  unbounded within EA_HORIZON_DAYS.
- No category or price ever published on this site; both always null.
