# genussregionen

url: https://festival.genussregionen.at/
method: html (regex on server-rendered page, no ld+json, no XHR data endpoint)

This is a single-purpose annual festival landing page, not a listing site. It
shows a recap of the most recent GENUSS-FESTIVAL and a "Save the Date" line
for next year's edition, e.g.:
  `Save the Date 2027:</strong><br>Muttertagswochenende, <strong>7. bis 9. Mai</strong> im Wiener Stadtpark`

scrape.py regexes that sentence for year/day-range/month/venue and emits ONE
occurrence per run. The site only ever publishes ~1 event ~a year ahead
(next Mother's Day weekend); horizon_days is irrelevant here.

Breaks if: the "Save the Date" wording changes, or the site switches to
publishing a real program (would then need per-slot scraping instead).
Re-derive by curling the URL and grepping for "Save the Date".
