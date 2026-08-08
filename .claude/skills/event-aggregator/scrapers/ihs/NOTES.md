# IHS

- url: https://www.ihs.ac.at/news-and-events/events-calendar/
- method: html. Listing page has `div.events article` blocks with title/url and a
  short date box, but only a single day even for multi-day events. Each item's detail
  page is fetched for the accurate `<time itemprop="datePublished" datetime="...">`
  start/end pair, the time range, and venue text after the time tags.
- The IHS calendar is sparse: only 2 upcoming events were listed at scrape time
  (Sep and Oct 2026), no pagination present. Site publishes whatever is currently
  scheduled, no fixed horizon; re-run periodically to catch newly added events.
- No category or price info anywhere on listing/detail pages; category left null,
  price_min left null (never seen a price mentioned).
- Breaks if: the `events article` / `time-location` / `itemprop="datePublished"`
  markup changes, or if TYPO3 template structure is reworked.
- Past events at /news-and-events/events/past-events/ — not scraped (not needed,
  scraper only wants upcoming).
