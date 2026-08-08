# srs (Spanische Hofreitschule)

- url: https://www.srs.at/de/tickets/<slug> for each of 10 event-type pages
  (vorfuehrung, morgenarbeit-mit-musik, gefuehrter-rundgang[-en],
  architekturfuehrung/architectural-tour, kinderfuehrung,
  legende-lipizzaner[-en], briefe-ans-christkind).
- method: html. Each page has a server-rendered calendar of upcoming
  occurrences ("event-details-ticket-item" blocks with day/month/weekday,
  optionally a time, and per-category (Kat. N) or per-timeslot ticket rows
  with € prices). Default view only shows ~4 weeks, so the scraper first
  GETs the page for a CRAFT_CSRF_TOKEN + session cookie, then POSTs
  action=srsfilter/filter/set with fromDate/toDate (today..horizon,
  DD.MM.YYYY) to widen the range — site caps it at ~12 months ahead but in
  practice stops publishing new dates around end of current year.
- All occurrences share one venue/address (Michaelerplatz 1, 1010 Wien);
  hardcoded rather than parsed.
- "Geführter Rundgang" / "Architekturführung" pages list multiple time
  slots per day (e.g. 13:00-14:00, 14:00-15:00, ...) with a single price
  column instead of Kat. rows — handled as a second parse branch.
- Excluded erlebnisse-piber (hub page, links to Piber/Steiermark products,
  not Vienna) and the veranstaltungen-wien overview page itself (lists
  event *types*, not dated occurrences).
- Breaks if: the CSRF form field name/action value changes, the
  "event-details-ticket-item" markup is restructured, or the site starts
  requiring a different session/cookie flow.
- Re-derive: curl one of the tickets/<slug> pages, diff against the
  regexes in scrape.py.
