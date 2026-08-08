# sargfabrik

- url: https://www.sargfabrik.at/veranstaltungen — server-rendered HTML, no
  JSON-LD/XHR. A `<select name="month">` on that page lists every month that
  currently has events (e.g. 2026-09 .. 2027-05, ~9 months out); fetch
  `?month=YYYY-MM` per option up to `ea.horizon()`, results have day/month
  but no year, so the year is taken from the query param, not parsed text.
- method: html. Each occurrence is a `<div class="event-calendar-item">`
  block with date/time, title, subtitle, and two tag spans: the first
  (`font-bold`) is the room/area (Kulturhaus, Badehaus, Raum für Wohnen,
  Kantine 14 -> becomes `venue` suffix), the second is the event's own
  category tag(s), comma-joined, used verbatim as `category`.
- price is NOT in the listing (only an ntry.at ticket-widget script tag) —
  one detail-page fetch per event, first `<div class="bard__module text
  mb-8">Eintritt: € X / € Y (...)</div>` block gets `ea.price()`'d. ~40% of
  events (kids' shows, Philosophisches Café, etc.) genuinely have no price
  text on the page -> price_min null, correctly, not a guess.
- venue: hardcoded single site, Goldschlagstraße 169, 1140 Wien.
- horizon: with EA_HORIZON_DAYS=180 (default), pulls ~98 records through
  Sep 2026-Feb 2027; density falls off sharply after Jan (2 in Feb, 2 in
  Mar, 1 each in Apr/May) — the site just doesn't have much booked that far
  out yet, not a scraper bug.
- breaks if: the month `<select>` markup or its option values change, the
  `event-calendar-item` block layout changes, or the `Eintritt:` price
  wording/wrapper div changes.
- re-derive: refetch /veranstaltungen, diff the month-select options and
  one event-calendar-item block plus one detail page's Eintritt div.
