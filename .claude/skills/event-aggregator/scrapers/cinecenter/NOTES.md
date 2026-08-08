# cinecenter

- url: https://www.cinecenter.at/ (homepage). Real showtimes are NOT on this
  domain: /tagesprogramm and /wochenplan embed an iframe pointing at
  `https://ticket.cinecenter.at/control/res_main.aspx?PrgMode=0|2`, an
  ASP.NET WebForms booking system (FO sinema). Scraper hits that directly.
- method: html. Week view (`PrgMode=2`) server-renders a table of films x 7
  day-columns with `<a ... PrgID=...>` showtime links. Its date-picker
  `<select>` offers jump points: each of the next 7 days, then the 14th of
  each of the following ~5 months (special one-off preview screenings, e.g.
  a "Love Birds" series). Scraper POSTs `__doPostBack` for each dropdown
  option beyond the initial week, reusing the first page's viewstate (works
  fine un-chained).
- Regular programme only actually covers ~1 week ahead; the monthly jump
  dates are sparse one-off previews, not the real horizon. Don't expect
  dense coverage past ~day 7.
- Per-film metadata (Genre, description) fetched once per distinct film id
  from `res_main.aspx?op=info&ID=<id>` and cached; that endpoint sometimes
  times out transiently, scrape.py retries 3x then falls back to nulls.
- No per-showtime price is published (only a general tiered price list at
  /preise); price_min/price_text always null.
- Breaks if: FO sinema markup changes (`sinemaPrg times` table class, the
  `<td valign='top'>` literal used to split day columns, or the ASP.NET
  field names `prg1$ddDatePicker` / `__VIEWSTATE` etc).
- image: same `res_main.aspx?op=info&ID=<id>` detail page already fetched
  for genre/description has the poster at `<figure class="image_container
  float_left"><img src="...">`; no extra request. duration_min was
  already being parsed from the showtime's `title='HH:MM - HH:MM (NN
  min)'` attribute - unchanged, 100% fill.
- per-film detail fetches were sequential and, combined with this
  backend's flakiness, occasionally starved description/category fill
  well below the 90% floor (and once took 3m40s). Switched to
  ThreadPoolExecutor (8 workers, 4 retries each) over the distinct film
  ids - faster AND more reliable since a slow/failing request no longer
  blocks the others. Don't revert to sequential.
