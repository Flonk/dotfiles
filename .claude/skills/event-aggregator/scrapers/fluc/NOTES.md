# fluc

- url: https://www.fluc.at/programm/ (302s to current-week `YYYY_Flucwoche##.html`)
- method: html. Ancient hand-rolled calendar, one `<li id='d_YYYYMMDD'>` per day, with a
  nested `<li id='f_YYYYMMDD'>` (Fluc) and `<li id='w_YYYYMMDD'>` (Fluc Wanne) cell.
- Scraper walks ISO weeks from this Monday forward (URL = `{isoyear}_Flucwoche{isoweek:02d}.html`),
  stopping at EA_HORIZON_DAYS. Week numbering follows Python's `date.isocalendar()`; a
  handful of weeks (e.g. the ISO week-53 gap at a year boundary) 404 and are just skipped.
  A stray placeholder day `d_19700101` (epoch bug on the site) is filtered by year<2020.
- Cell text is free-form German ("22:00: <strong>Title</strong>", "18.30 Titel",
  "abgesagt ...", "ev. ...", "fixiert: ..."); scrape.py regex-extracts a leading time
  (or HH:MM-HH:MM range) and strips noise prefixes (abgesagt/ev./event./fixiert:/#) from
  the title. "abgesagt" also sets status=cancelled.
- Real programme only goes out ~6-7 weeks (through late Sept 2026 at build time); weeks
  further out exist as empty template pages, so yield tapers off well before the horizon.
  This is expected, not broken.
- No per-event URL/price/category on the site: url = the week page, price_min/text and
  category always null. Single fixed venue (Praterstern 5, 1020 Wien) for both rooms.
- Re-derive: refetch a week page, diff against the regex in DAY_RE/CELL_F_RE/CELL_W_RE.
