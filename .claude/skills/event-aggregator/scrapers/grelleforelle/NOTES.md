# grelleforelle

- url: https://grelleforelle.com/programm
- method: html, server-rendered Divi/WordPress portfolio grid, no pagination
  (all upcoming events fit in one grid; `data-posts-number="100"`).
- Each listed item's title starts with `DD/MM ` (the actual date, sometimes
  differing from the URL slug after a reschedule). Year comes from the
  `project_category_20XX` class on the item div. Genre (`club`/`live`) comes
  from `project_category-(club|live)`.
- Door time is fetched from each detail page's `DOORS<br/>HH:MM` block (one
  extra request per event, ~17 events currently — cheap).
- No price is published anywhere on the site, only ticket-vendor links
  (eventim, tickethead, ticketmaster, ...) — price_min/price_text always null.
- No venue address/postal code published on either list or detail pages —
  district/address left null rather than guessed.
- Site itself publishes ~7 months out (through mid-March 2027 at scrape time);
  no need to paginate, just take everything on the page and drop past dates
  (the list occasionally mixes in an event from yesterday).
