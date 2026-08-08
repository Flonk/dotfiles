# azw (Architekturzentrum Wien)

- url: https://www.azw.at/de/programm/
- method: html (server-rendered, no ld+json, no XHR needed)
- Page has two `<ul>` lists: `id=exhibition-events-list` (Ausstellungen) and
  `id=upcoming-events-list` (Termine). Each `<li class=event-list_item>` carries
  `data-category`, `data-startDate`, `data-endDate` attrs plus a card with title,
  label (used as `category`), excerpt, "Ort: ..." venue line, and an optional
  `event-card_time` span (e.g. "17:00-18:00") parsed for the start time.
- All events on this one page already extend to ~mid-Dec 2026 (~4 months out);
  no pagination or per-event fetch needed. Past exhibition archive lives under
  `/de/programm/ausstellungen/archiv` (not scraped, not needed).
- One exhibition (Suburbia, "on Tour in Linz") is outside Vienna; hardcoded
  venue->city override in scrape.py (`NON_VIENNA` dict) for that case.
- No prices shown anywhere on the listing, so `price_min`/`price_text` are
  always null — never inferred.
- "Hot Questions – Cold Storage" has a fabricated far-future `data-endDate`
  (`2035-02-03`) — the card is labeled `permanente Ausstellung` in
  `event-card_date`; detect that and emit `end: null`, `extra.permanent: true`
  instead of the sentinel date.
- Breaks if AZW restructures the event-card markup (class names) or drops the
  `data-startDate`/`data-endDate` attributes. Re-derive by curling the URL and
  diffing against the `<li class=event-list_item ...>` block structure.
