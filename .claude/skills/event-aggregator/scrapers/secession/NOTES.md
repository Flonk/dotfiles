# secession

- url: https://secession.at/category/exhibitions (NOT www.secession.at/ausstellungen/, which
  redirects to a 404-ish "Keine Ergebnisse gefunden" page)
- method: html. No ld+json, no API. Server-rendered `<li class="exhibCatElem">` items under
  three `<h2>` sections: "Aktuell" (current), "Beethovenfries" (permanent, dates say
  "permanent"), "Zukünftige Ausstellungen" (future). All on one page, no pagination.
- date format: `DD.MM. – DD.MM.YYYY` (same year, year only on end) or
  `DD.MM.YYYY – DD.MM.YYYY` (year on both, e.g. exhibitions spanning Dec–Feb). Parsed via
  regex + ea.de_date.
- Beethovenfries item is hardcoded as permanent: start=today, end=None, extra.permanent=True.
- No per-exhibition category or price on the listing; left null rather than guessed. Detail
  pages have long descriptive text but no structured category/price either.
- Site publishes exhibitions ~6 months out (through Feb 2027 as of writing). Breaks if the
  markup class names (exhibCatElem/exhibSliderArtist/exhibSliderWork/exhibSliderDate) change,
  or if the "permanent" literal for Beethovenfries changes wording.
