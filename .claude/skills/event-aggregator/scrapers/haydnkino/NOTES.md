# haydnkino

- url: https://www.haydnkino.at/Cinema/Overview
- method: api (XHR endpoints behind the SPA-ish page)
- `/Cinema/CurrentList?dateSel=DD.MM.YYYY` returns the day's movie cards with
  exact showtimes (prgId/screenId/Saal letter). Calling it without an
  `Accept-Language` header (e.g. `de-AT,de;q=0.9,en;q=0.8`) makes the ASP.NET
  backend 500 — `ea.fetch` already sends that header by default, so plain
  usage works.
- Every CurrentList response embeds a flatpickr `enable: [...]` array — the
  full, identical-regardless-of-date list of every date with confirmed
  showtimes (~2 months out from today). Scraper fetches it once, then hits
  CurrentList for each of those dates.
- `/Cinema/PreviewList` (no params) lists titles announced further out, only
  with a "Startet am DD Mon YYYY" date, no time yet. Emitted as date-only
  records, deduped against filmIds already seen via CurrentList.
- No price anywhere on site (listing, detail, or reserve pages) — price_min
  always null.
- Single venue/address, hardcoded; "Saal <letter>" appended to venue per slot.
- Re-derive: view-source the Overview page network calls, or just re-run
  curl against CurrentList/PreviewList with an Accept-Language header.
