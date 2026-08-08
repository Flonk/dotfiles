# vetmeduni

- url: https://www.vetmeduni.ac.at/universitaet/infoservice/veranstaltungen
  (the url originally in meta.json, .../de/... with a JSON-LD claim, 404s —
  no de/ prefix on this site, and it has no Event JSON-LD anyway)
- method: html. TYPO3 news list, 6 items/page, `/page-2`, `/page-3`, ...,
  sorted ascending by date. scrape.py paginates until the last date on a
  page passes the horizon, then GETs every detail page (threaded).
- Detail pages carry labelled plain-text fields: `Ort:`, `Veranstaltungsbeginn:`,
  `Veranstaltungsende:`, `Veranstaltungskategorie:` — scrape.py regexes those.
- Publishes ~3.5 months out at build time (through mid-December from an
  early-August run). Re-derive by re-checking how many `page-N` links exist
  before dates exceed the horizon.
- venue fill ~60%: some entries (online seminars, internal "Akademische
  Feier" ceremonies) simply have no `Ort:` line on the site — left null,
  not guessed. price is almost always unstated (null); district rarely
  resolves since most venues are outside Vienna postal codes.
- Environment note: this sandbox intermittently throws "No route to host"
  under load; scrape.py retries fetches up to 8x with a 3s backoff.
