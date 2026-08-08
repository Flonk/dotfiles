# literaturhaus

- URL: https://www.literaturhaus-wien.at/programm/veranstaltungen/ (root `/` is the homepage,
  no events there — redirect target is `/programm/veranstaltungen/`).
- Method: html. No `Event` ld+json (only WebPage/Breadcrumb/WebSite). Server-rendered
  `<div class="event">` cards each hold an `<a class="item-scope" href>`, `date-info`
  (German short date, "Sa, 11.7.2026" or a range "D.M.YYYY - D.M.YYYY", ", HH.MM" time
  suffix), `title`, optional `#TAG` chips (used verbatim as `category`), optional
  `description` teaser.
- Pagination: `/programm/veranstaltungen/seite/2/`, `/seite/3/`, ... `EVENT_RE` split on the
  literal `<div class="event">` string; loop stops when a page has no `seite/{n+1}/` link.
- Site only actually publishes ~2.5 months of listings ahead (3 pages, 18 events, last one
  Oct 2026 as of Aug 2026 run) — horizon_days is mostly irrelevant here, pagination just
  runs out.
- No price anywhere (listing or detail page) — `price_min`/`price_text` always null.
- Venue/address/district hardcoded: Literaturhaus Wien, Zieglergasse 26A, 1070 Wien.
- Re-derive: refetch the URL, check `class="date-info"` / `class="event"` / `item-scope`
  still present; if WordPress theme changed, re-inspect card markup.
