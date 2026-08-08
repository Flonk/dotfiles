# jazzland

- url: https://www.jazzland.at/ — old frameset site (index.htm/home.php in
  frames); real content lives under prog/ (bimonthly "Jazzland Post"
  bulletin, iso-8859-1 encoded).
- method: html. `jl_menu.php` has an `<a href="prog/jlpMMYY.htm"
  title="aktuelles Programm">` link giving the *current* bulletin filename
  (e.g. jlp0726.htm = Jul/Aug 2026); scrape.py resolves this dynamically
  each run instead of hardcoding it, since the filename changes every
  publish cycle.
- The bulletin's overview `<table class="uetab">` has one `<tr>` per
  band/booking with a date cell (`title="YYYY"`, `<br>`-separated
  weekday.day.month, e.g. "Sa.22.8."), title, short description, a
  category cell (`title="Traditional Jazz, ..."` = verbatim genre labels,
  content = letter codes B/T/S/M/L), and a `#D...` anchor to the detail
  section. A multi-date row (residency/festival) becomes one record per
  date. The closed-for-summer row and the trailing legend row have no
  `#D` anchor and are skipped by that filter.
- Site publishes only the current bulletin — no next-period page exists
  yet (menu literally says "Vorschau - folgt!"); as of build time that's
  ~3 weeks of real horizon (mid-to-end Aug 2026), far short of the 180d
  default. Nothing to be done — re-run periodically to catch new bulletins.
- No per-event prices published (door price only, ~EUR 15-22 depending on
  band) — price_min always null, price_text carries the generic range.
- breaks if: `class="uetab"` markup changes, or the "aktuelles Programm"
  menu link text/href pattern changes in jl_menu.php.
