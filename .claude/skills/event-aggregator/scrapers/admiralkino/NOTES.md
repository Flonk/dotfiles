# admiralkino

- url: https://www.admiralkino.at/ — front page embeds a JS widget
  (`cinema-showtimes.js`) that POSTs `action=get_ajax_posts` to
  `wp/wp-admin/admin-ajax.php` and gets back the *entire* known programme
  as JSON (not paginated/date-scoped; the JS filters client-side per day).
- method: api. Fields per item: title, start_date ("8. August 2026"),
  start_time, datetime (unix ts), duration, remarks, categories, language,
  url (`/produktion/<slug>/`). No id field, so source_id is
  `<slug-from-url>-<datetime>`.
- as of build time the cinema is in "Sommerpause" (closed 3.-20. Aug 2026);
  the feed represents that as 13 daily placeholder rows titled
  "SOMMERPAUSE" pointing at a closure-notice production page — these are
  filtered out (not real screenings), leaving 7 real upcoming events.
- price is never published anywhere (listing or detail pages link out to
  an external ticket widget) — price_min/price_text always null, by design.
- venue/address/district are hardcoded (single-venue cinema): Admiral
  Kino, Burggasse 119, 1070 Wien (from /impressum/).
- horizon: site currently only lists ~7 events out to 24 Dec 2026 (~140
  days out), roughly one every 2-3 weeks — sparse but genuinely that far
  ahead, so horizon_days set to 180.
- breaks if: admin-ajax action `get_ajax_posts` is renamed/removed, or the
  JSON field names (title/start_date/start_time/datetime/url) change.
- re-derive: view-source the homepage, find the `cinema-showtimes.js`
  script tag, read its `$.ajax` call for the current action name.
- image: `og:image` meta tag on each `/produktion/<slug>/` detail page,
  fetched concurrently (ThreadPoolExecutor, 8 workers, 3 retries each) —
  this host was flaky under load, keep the retries.
- runtime: the ajax feed already carries a `duration` field ("103
  Minuten") per item — parsed straight into `extra.duration_min`, no
  detail-page fetch needed for that part.
