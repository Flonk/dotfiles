# albertina

- URL: https://www.albertina.at/ausstellungen/ (single page, no pagination). Method: html.
- Listing page has `<div id="aktuell">...`/`<div id="vorschau">...` sections with `<a href>` links to
  detail pages, some under `/ausstellungen/<slug>/` (Albertina) and some under
  `/albertina-modern/ausstellungen/<slug>/` (Albertina Modern). No dates on the listing itself.
- Each detail page has a plain-text sentence `ist von <start> bis <end> [in der ALBERTINA MODERN]
  zu sehen` (dates as German "17. April" / "16. August 2026" — start often omits the year, taken
  from the end date's year). Regex-parsed with `ea.de_date`.
- Permanent installations (no such sentence: 250 Jahre Albertina, Monet bis Picasso, Prunkräume)
  get a synthetic start=today, end=today+3y.
- Site publishes real dates for temporary shows ~2-9 months out (furthest seen: Down Under,
  ends 2027-05-02). No pagination to exercise the horizon.
- venue derived from URL path (`/albertina-modern/` -> "Albertina Modern"), district hardcoded 1010.
- No price or category info anywhere on the site's exhibition pages — both always null.
- Re-derive: if `id="aktuell"` or the "ist von ... zu sehen" sentence wording changes, re-fetch and
  re-inspect a detail page.
