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
- image: each `/Cinema/Movie?filmId=N` detail page has `<img src="/FilmImg/<slug>.jpg">`
  in the poster block; joined onto BASE. runtime/origin text lives right after
  the detail page's `<h1>` as `Genre<br/>NN min, Country Year<br/>...` — kept
  verbatim as `extra.origin_year_runtime`. Both fetched via a ThreadPoolExecutor
  over the unique film urls found across CurrentList+PreviewList.
- The server itself is slow and occasionally unreliable under concurrent load
  (hangs, hard timeouts, transient DNS/routing errors) — day-list and detail
  fetches use 6 workers / 30s timeout / 1 retry each. A naive sequential
  60s-timeout loop over every enabled date routinely blew past check.py's
  300s kill; don't revert to sequential fetching.
