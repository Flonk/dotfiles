# viennashorts

- url: https://www.viennashorts.com/ (Kirby CMS, static HTML, robots allows all)
- method: html — regex over `ea.text()` of homepage for
  "N. Internationales Kurzfilmfestival D. – D. Month YYYY" to get the next edition's
  dates/edition number. Separately fetches /besuch-uns/ticket-infos and regexes the
  "X € – <tier name>" list to get min ticket price (currently 4 EUR).
- No per-film/screening schedule exists in HTML: the "programmsuche" page and the
  "Filme streamen" catalogue are empty/client-rendered off-season. So this emits ONE
  record for the whole festival week, like a months-long exhibition would be.
- Only the next unstarted edition is ever announced (currently 25.-30. May 2027, ~9.5
  months out — beyond the 180d horizon default, but still the single available record).
  venue/district left generic/null since the festival spans ~10 different cinemas.
- Breaks if: the homepage headline wording changes (regex anchors on literal
  "Internationales Kurzfilmfestival"), or the ticket-infos price list format changes.
  Re-derive by re-fetching both pages and re-checking the two regexes.
