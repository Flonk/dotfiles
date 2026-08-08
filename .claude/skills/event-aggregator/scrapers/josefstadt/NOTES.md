# josefstadt

- url (meta): https://www.josefstadt.org/programm/spielplan.html — just a wrapper with
  `<iframe src="/webshop/shop/spielplan_stuecke.aspx">`. Real listing lives at that aspx.
- method: html. ASP.NET WebForms page; default GET returns the first available month
  (currently Sept 2026 — theatre is dark in August, so no Aug data exists at all). Other
  months are reached via `__doPostBack` on the month `<select>`; scrape.py replays this
  as a plain POST with `__VIEWSTATE`/`__VIEWSTATEGENERATOR`/`__EVENTVALIDATION` scraped
  from a fresh GET each time (viewstate is self-contained, no session/cookie needed).
- Two venues (Theater in der Josefstadt 1080, Kammerspiele der Josefstadt 1010) render as
  two grid columns per day; Sträußelsäle shows are folded into whichever column, not
  broken out — venue/district are set from the column, not always literally accurate.
- Publishes ~10 months ahead via the dropdown (through next June); scrape.py stops at
  `ea.horizon()`. "keine Vorstellung" placeholder cells (dark days) are skipped.
- price_min/category: ticket price tiers only appear once sales open for that date (rare
  in the listing), so both are usually null — not guessed.
- Breaks if: the postback control ids change (`ctlMonateListe$ctlMonthDropdown`,
  `ctlRepeater...ctlName_N`/`ctlDatumLarge_N`/`ctlZeit_N`), or the iframe src path moves.
