# meinbezirk

- URL: https://www.meinbezirk.at/event/wien/list/all/{page}?eventitem_filter_simple[date_start]=YYYY-MM-DD&eventitem_filter_simple[date_end]=YYYY-MM-DD
- Method: server-rendered HTML, no JSON-LD or API. Parse `<article class="content-list-item content-card content-card-default|listview" data-eventitem-id="...">` blocks.
- Fields: title/url from the `<h3><a>`; date+time from the first `<li>` in `.content-card-date-location` (via `ea.de_date`); venue from the 2nd `<li>` when 3 are present; district + category parsed out of the URL path `/event/<district-slug>/c-<category-slug>/<slug>_e<id>` (hardcoded slug maps, 23 districts + ~12 categories seen so far).
- Price: list/detail pages have no structured price. Only set `price_min=0` when the teaser description matches a tight "Eintritt frei/kostenlos/gratis" phrase regex (not a loose "frei" keyword — that false-positives on things like "frei von Symbolik").
- Pagination: loop `/all/{page}` until a 404 (site reports up to ~24 pages for a 30-day window). Site's own paging reorders/duplicates events across pages non-chronologically, so dedupe by event id and don't stop early on an empty page — keep going to the 404. Added a small retry since occasional page fetches were flaky and truncated the run.
- Horizon actually published: results only run out around 24-45 pages depending on date_end; kept `horizon_days: 30` to stay fast (~24 fetches/run).
- Re-derive: refetch the current-week URL, diff selectors if `content-card-date-location` or the article class names change.
