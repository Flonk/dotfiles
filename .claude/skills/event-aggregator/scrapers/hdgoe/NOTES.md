# hdgoe

- url: https://www.hdgoe.at/ (canonical host hdgoe.at, www redirects). robots.txt only
  disallows /items/ and /CMS/items/, calendar/exhibition pages are fine.
- method: api. The calendar page (`/category/kalender`) loads `fullcalendar` via a POST
  to `Frontend/load_calendar_events` with `start=YYYY-MM-DD`, returning JSON events for
  that 7-day window only — paginate weekly from this Monday out to `ea.horizon()`.
- Only keep `cat_id` in {81 Führungen, 143 Kinder- & Jugendprogramm, 147 Veranstaltungen}
  (matches the site's own filter legend). Other cat_ids seen (0, 9, 20) are English-
  language duplicate rows and "opening hours changed" admin notices, not real listings.
- The 4 currently-running exhibitions live on the same `/category/kalender` page in the
  `currentProgramElemHolder` block (title/url/teaser); dates are parsed from the teaser
  plus the first descriptive paragraph of the detail page (`Ab D. Monat YYYY` or a
  `D. Monat–D. Monat YYYY` range). No date text at all -> `extra.permanent: true`.
- price_min: 0 only for cat_id 147 (site states "Teilnahme an Veranstaltungen ist
  kostenlos"); exhibitions get general admission price scraped from /zeiten-preise
  ("Erwachsene € N"); tours/kids programs left null (fee structure ambiguous — some
  tours are included, some cost extra on top of admission).
- Site publishes the weekly calendar roughly through year-end (tested to ~180 days out,
  no sign of a hard cutoff before then).
- Breaks if: `Frontend/load_calendar_events` response shape, `cat_id` legend, or the
  `category_list_item`/`currentProgramElemHolder`/`module module_text` HTML class names
  change. Re-derive by curling `/category/kalender` with a browser UA and grepping for
  `load_calendar_events` in the loaded `calendar.js`.
