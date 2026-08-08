# messecongress (VIECON Messe Wien)

- url: https://www.messecongress.at/ redirects (301) to https://vieconcenter.at/ (rebrand).
  Actual scrape target: https://vieconcenter.at/events (+ /events/p2, /p3, ... paginated).
- method: html. Server-rendered `<li class="h-full rounded-[16px] ...">` event cards,
  no JSON/ld+json available. Regex-parsed for title (`<h3 class="font-bold">`), date
  span, and icon-labelled spans (place/entrance/organisator/ubahn/extLink).
- Dates come in 3 formats on one line: `DD.MM.-DD.MM.YYYY`, `DD.-DD.MM.YYYY`,
  `DD.MM.YYYY` (single day). Parsed in that priority order.
- No category or price info on the listing at all -> both always null.
- Venue is a single physical site (Trabrennstrasse 7, Prater) -> district hardcoded 1020.
- Only ~10 events total across 2 pages; furthest one currently ~March 2027 (trade fairs
  booked far ahead — site is not horizon-limited, just sparse).
- Breaks if: the `event-card` / `h-full rounded-[16px]` markup changes, or vieconcenter.at
  changes domain/URL structure again.
- Re-derive: `curl -L https://vieconcenter.at/events`, look for `<li class="h-full
  rounded-[16px]...">` blocks and `icons/<field>.svg` labelled spans inside.
