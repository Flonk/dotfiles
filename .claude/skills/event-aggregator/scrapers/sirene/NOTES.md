# sirene Operntheater

- url: https://www.sirene.at/
- method: html. No ld+json, no API. Tiny TYPO3-ish static site.
- `/projekte/` has a nav (`#menu_sub`) listing every production ever done,
  newest first, as `<a href='/projekte/<slug>/'>YYYY Title</a>`. We take
  entries whose leading year >= current year - 1, fetch each detail page,
  and regex the plain-text content for date lists like
  "21., 22., 23. ... November 2026, jeweils um 19:30 Uhr" -> one record
  per day. Past dates (e.g. last year's already-played production) are
  dropped by comparing against today.
- Venue/address parsed from "Jugendstiltheater , Baumgartner Höhe 1, 1140
  Wien" text near the date line; only that one venue has ever appeared.
- No price info anywhere on site (tickets via owa-wien.at) -> price_min/
  price_text left null unless "frei"/€ text literally appears.
- This company runs roughly one production a year, announced months
  ahead (Aug 2026 page already had the Nov 2026 run listed) - horizon
  set generously (400d) since there's no pagination/volume concern.
- Breaks if: the `<div id="content">` markup changes, the nav loses the
  `<a href='/projekte/<slug>/'>` top-level pattern, or the date-list
  phrasing changes (currently "D., D., ... Monat YYYY[, jeweils um HH:MM
  Uhr]"). Re-derive by refetching /projekte/ and a detail page and
  reading the plain text ea.text() produces.
