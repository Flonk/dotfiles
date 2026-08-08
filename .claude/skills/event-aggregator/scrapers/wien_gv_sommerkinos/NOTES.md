# wien_gv_sommerkinos

- url: https://www.wien.gv.at/kultur/sommerkinos — plain server-rendered HTML, no ld+json Events
  and no XHR/API; it's a hand-maintained editorial page listing ~10 open-air cinema
  festivals for the current summer.
- method html: split on `<h2><span id="...">` blocks (one per festival). Each block's `<ul>`
  has free-text `<li>` items: official link, `Termin(e): ...` (German date prose), `Ort: ...`
  (address, sometimes an `<a>` to the Wien Stadtplan), optional `Eintritt frei`.
- Date prose is parsed with local regexes (not `ea.de_date`, formats are too varied): "X. bis
  Y. Month YYYY" ranges collapse to one record; comma/"und"-separated single dates (no "bis")
  become one record each (past ones dropped); the "Sunset Cinema" block has a nested list of
  venue+date-range pairs, each becoming its own record.
- district derived from the leading `N.,` Bezirk prefix in the Stadtplan address text.
- category is the page's own breadcrumb tag ("Film und Kino"), same for every record verbatim.
- Site only publishes the current season (no history, no next year yet) — effectively no real
  horizon/pagination concept; whatever's listed is everything there is until it's edited next.
- Breaks if: the site restructures away from `<h2 id>` + `<ul><li>Termin:/Ort:</li></ul>`, or
  rephrases date prose outside the "X. bis Y." / "D., D. und D. Month" / "von X bis Y ... Uhr"
  patterns handled here. Re-derive by rereading the block manually and adjusting `parse_termin`.
