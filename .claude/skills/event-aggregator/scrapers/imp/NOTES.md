# imp

- url: https://www.imp.ac.at/calendar
- method: html (server-rendered list + offset-paginated partial HTML, no JSON API/JSON-LD)
- Pagination: first page has `data-perpage='15'` and `data-all='N'` on the
  "Show more" button; subsequent pages fetched from
  `https://www.imp.ac.at/index.php?id=222&type=8881&cat=&beginndate=&enddate=&keyword=&offset=N`
  which returns the same `events__item` HTML fragments, no wrapper.
- Each `.events__item` gives date (day/month/year divs), optional time,
  title+href (source_id = trailing `-<digits>` in the slug), venue
  (`events__item-title`), speaker + institute (`events__dl`/`dd`), and an
  optional category tag (`span.tag`, e.g. "Monday Seminar").
- Site publishes seminars roughly 3 months out (110 events total on the
  calendar at time of writing, tailing off around Nov 2026 for a 90-day
  horizon). No price or address/district info anywhere — left null, not guessed.
- Breaks if TYPO3 markup/class names change, or if the offset API path
  (`id=222&type=8881`) is renumbered — re-derive by viewing the "Show more"
  button's `data-url` on the calendar page.
