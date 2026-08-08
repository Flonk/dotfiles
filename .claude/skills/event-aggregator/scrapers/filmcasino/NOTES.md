# filmcasino

- url: https://www.filmcasino.at/ — homepage is a WordPress theme, real
  schedule lives at /programm/?show=this (next ~7 days) and
  /programm/?show=next (following ~6 days). Both server-rendered.
- method: html. Each page has a `.sp-resp` section with one `<table>` per
  day; rows are `<tr class=" cinemaN">` with title `<a>` + optional
  `<span class="disp-special">` (series label, used as `category`), then
  one `<div class="wrapper">` per showtime containing two `<a
  data-show_id=... aria-label="Tickets <Cinema> <Weekday> <D.M.>
  <HH:MM>">` tags (dedupe by data-show_id). No year in the markup —
  inferred from today's date, rolling to next year if >30 days in the past.
- two cinemas hardcoded from /kontakt/: Filmcasino (Margaretenstraße 78,
  1050) and Filmhaus Spittelberg (Spittelberggasse 3, 1070).
- horizon: site only publishes ~13-14 days of exact showtimes (this+next);
  a further /programm/?show=preview page lists later premieres by month
  but without exact times/showtimes, so it's not scraped — horizon_days
  set to 14, honestly reflecting what's available.
- price never published on the schedule pages; price_min/price_text
  always null.
- breaks if: the `.sp-resp` table markup, `ticketlink`/`data-show_id`
  attrs, or the "Tickets <cinema> <weekday> <d.m.> <hh:mm>" aria-label
  format change. Re-derive by curling /programm/?show=this and grepping
  for `class="wrapper`.
