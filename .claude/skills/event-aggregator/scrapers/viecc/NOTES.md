# viecc

- url: https://www.viecc.com/ — a single WordPress homepage for the annual convention, no
  events listing/archive. This is a single-occurrence source by nature (one 2-day fair per
  year); the scraper emits exactly one record per run.
- Method: html. The page's own JSON-LD graph has no Event node (only WebPage/WebSite/
  Organization), so dates/venue/price are parsed from the rendered text: date range from the
  "21. – 22. November 2026" heading, hours from the "Samstag: 10:00–20:00 / Sonntag:
  10:00–18:00" lines, address from "Messeplatz 1, 1020 Wien", ticket prices from the "Adult
  Samstag/Sonntag/Weekend € NN" blocks (price_min = cheapest listed).
- Publishes only the current/next edition (Nov 2026 as of this build) — no forward horizon
  beyond that, since it's a yearly one-off, not a recurring calendar.
- Breaks if: the date-range heading format changes, or the Öffnungszeiten block is reworded.
  Re-derive by curling https://www.viecc.com/ and grepping for "Öffnungszeiten" / "€".
