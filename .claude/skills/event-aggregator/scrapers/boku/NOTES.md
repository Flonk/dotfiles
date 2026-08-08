# boku

- url: https://boku.ac.at/event/list, method: html (+ per-event .ics feed)
- robots.txt allows crawling with `Crawl-delay: 10`; no ld+json, no JSON API.
- Listing is server-rendered, one month per page: `/event/list/{year}/{month}`
  (links use unpadded month numbers, e.g. `.../2026/9`). Each `<a class="corner-link"
  href="/event/details/{id}">` block has title (`<h4>`), category (`title="Kategorie"`
  list) and a teaser `<p>`, but only a coarse date — no reliable end time/date.
- Exact start/end/location: fetch `/event/details/{id}.ics`. TZID is already
  Europe/Vienna, DTSTART/DTEND are local wall-clock, no conversion needed.
  Long-running exhibitions (e.g. months-long gallery shows) get one record
  spanning DTSTART..DTEND from the ics, deduped across the months they appear in.
- The current month's list page includes days already in the past (site doesn't
  filter server-side), so scrape.py drops any record whose end (or start, if no
  end) is before today.
- district/city only get filled when the ics LOCATION string ends in a Viennese
  postal code (1010-1230); many events are off-site (Krems, Tulln, Raabs) or
  "Online Event" and stay null — don't guess.
- Site publishes sparsely: about 9 events found within the default 90-day
  horizon (Aug-Nov 2026 at build time), one per 1-2 weeks. Increasing
  EA_HORIZON_DAYS just walks further month pages; volume stays thin.
- Re-derive: fetch https://boku.ac.at/event/list, confirm the corner-link/h4/
  Kategorie markup is unchanged, and spot-check one `.../event/details/{id}.ics`.
