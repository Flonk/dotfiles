# schikaneder

- url: https://schikaneder.at/jart/prj3/schikaneder/main.jart — Waystone/jart CMS, no ld+json, no JSON API.
- method: html. Walk `/kino/kinoprogramm?date=YYYY-MM-DD` day by day from
  today to `ea.horizon()`, regex out `veranstaltung_id=(\d+)` refs, dedupe.
  Fetch each `/kino/veranstaltung_detail?veranstaltung_id=<id>` once; it
  lists ALL of that film's remaining showtimes (`<div class="termin">` +
  `data-termin_id`/`data-datum`/`data-raum`), so per-day parsing of
  showtimes themselves is unnecessary — only used to discover ids.
- real published depth: despite the date-slider showing 60+ days of
  tappable date tabs, actual programme content stops after ~12 days (empty
  from ~day 14 on at time of writing); scan aborts after 14 consecutive
  empty days to save requests.
- price_min/text: no per-film price; taken once from the site's own
  "8,50 EUR Normalpreis" default-price box on `/kino/kinoprogramm`.
- category: always null — site has no genre/tag field (`subtyp` div is
  always empty).
- venue hardcoded: Schikaneder, Schleifmühlgasse 8/14, 1040 Wien (only one
  screening room, "Saal", appended to venue name).
- breaks if: `data-termin_id="..." data-raum="..." data-datum="..."`
  attribute order/names change, or `detail-titel`/`kurzbeschreibung` class
  names change.
- re-derive: view-source `/kino/kinoprogramm?date=2026-08-08` and any
  `/kino/veranstaltung_detail?veranstaltung_id=...` page.
- image: same detail page's `og:image` meta tag, but as printed on-site
  it's broken - `http://schikaneder.at:443/jart/pub-prc/img.jart?...`
  (plaintext HTTP against the TLS port 443, connection resets with an
  empty reply). Rewritten to `https://schikaneder.at/jart/pub-prc/
  img.jart?...` which 302-redirects to the real jpeg. 100% fill.
- duration: the `subinfo` div ("Regie, Land, Jahr<br>NNN min., OmdU")
  already parsed for description - added a regex for "NNN min" ->
  extra.duration_min. 97% fill.
