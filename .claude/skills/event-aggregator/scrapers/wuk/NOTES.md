# wuk

- url: https://www.wuk.at/programm/
- method: html. TYPO3 server-rendered event list, no JSON-LD.
- Pagination: each page has a "Mehr laden" link with `filter[...]&pPage=N&cHash=...`.
  The cHash is TYPO3-computed and can't be forged; must follow the link chain page
  by page (fetch page N, read its "Mehr laden" href for page N+1). Site naturally
  stops after ~6 pages / ~90 records (published ~9 months out, to spring 2027).
- Dates are free-text German phrases with many shapes (single date+time, "X bis Y"
  ranges, comma-separated day lists sharing one month/year, "&"/"und"-joined dates,
  month-name dates). Parsed heuristically in `parse_period`; rare multi-date entries
  may collapse to one occurrence — acceptable approximation.
- Price comes only from each event's own detail page (`Preis` block); not on the
  list page. One extra HTTP fetch per event (~90), ~20s total, well within budget.
  Missing price = external/ticketed shows with no price block on wuk.at (null, not guessed).
- Recurring non-dated listings (e.g. "jeden Di und Fr ... abholen") have no parseable
  date and are skipped.
- Venue district hardcoded to 1090 (WUK's home address) unless the venue text names
  a different postal code (seen once: WUK's Bräuhausgasse branch, 1050).
- Re-derive by re-fetching /programm/ and diffing the HTML structure around
  `event-list-item-meta-info` / `event-list-item d-flex`.
