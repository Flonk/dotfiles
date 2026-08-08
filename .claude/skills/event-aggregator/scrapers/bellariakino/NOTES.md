# bellariakino

- url: https://www.bellariakino.at/de — Next.js site, powered by the
  cineamo.com cinema platform (also used by votivkino, Kino De France).
- method: api. `GET https://api.cineamo.com/showings?cinemaIds[0]=3000&perPage=100&page=N`
  (cinemaId 3000 = Bellaria Kino) returns HAL-style paginated JSON, no
  auth/key needed, sorted ascending by `startDatetime`. Currently ~272
  total rows spanning past + future (site doesn't scope by date server
  side); we fetch all pages and filter locally to today..horizon.
- `startDatetime` is UTC (`...Z`); converted to Europe/Vienna via
  zoneinfo. Detail url is `/de/programm/<contentId>/<showingId>`
  (verified against the site's own link markup).
- `_embedded.content.category` is the literal string `movie_series` for
  every single row — it's the CMS content type, not a real genre; kept
  verbatim per instructions anyway.
- price never appears anywhere in the API; booking always redirects to an
  external ticket-cloud.de page, so price_min/price_text are always null.
- horizon: site's programme currently only reaches ~67 days out
  (2026-10-14 as of build); horizon_days set to 90, but expect the true
  published depth to fluctuate with how far ahead they've scheduled.
- breaks if: cineamo changes the `showings` endpoint shape, the
  `cinemaIds[0]=` query param, or the `_embedded.content` nesting.
- re-derive: view-source any page on bellariakino.at and grep for
  `api.cineamo.com`.
