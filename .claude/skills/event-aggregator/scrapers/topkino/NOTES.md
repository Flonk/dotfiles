# topkino

- url: https://www.topkino.at/ — no robots.txt (404), no ld+json, no API.
- method: html. `/kino/aktuell` (currently playing) + `/kino/demnaechst`
  (announced upcoming) list film detail links (`/kino/<slug>` or
  `/kino/veranstaltung_detail?veranstaltung_id=<id>`). Each detail page has
  a `Termine` block (`class="termin"`: `datum` "DD.MM.YYYY | HH:MM", `raum`,
  `data-termin_id`) — one record per termin. Title from `detail-titel`,
  director/country/year/runtime/language from `subinfo`, blurb from
  `kurzbeschreibung`. If a film has no termine yet (pure future release),
  falls back to its `filmstart` text ("am Do., 24. September") as a
  date-only placeholder record.
- also checked `/kino/kinoprogramm?date=YYYY-MM-DD` (a 61-day date-picker
  calendar, Aug 8 – Oct 7 at scrape time) — its per-day listing is a subset
  of what the film detail pages already expose, so not used; fetching ~8
  detail pages is cheaper than 61 day pages.
- real showtimes only extend ~2 weeks ahead per film; further out only a
  handful of premiere dates show up (e.g. one title had a single Sept 24
  screening already bookable while regular program only reached Aug 20).
- no genre/category field on site anywhere; `category` left null.
- no per-showtime price; sidebar mentions a general "8,50 EUR Normalpreis"
  (reguläres Spielprogramm) but it's not tied to any specific record and
  premieres/specials may differ, so `price_min`/`price_text` left null
  throughout — never guessed.
- single venue: Rahlgasse 1, 1060 Wien (confirmed via web search, not
  printed on the site itself — only a KG's legal/impressum address at
  Schleifmühlgasse 8/14, 1040 Wien shows up there, which is unrelated).
- breaks if: `detail-titel`/`subinfo`/`kurzbeschreibung`/`termin`/
  `data-termin_id` markup changes, or `/kino/aktuell` & `/kino/demnaechst`
  stop linking every currently-listed film.
