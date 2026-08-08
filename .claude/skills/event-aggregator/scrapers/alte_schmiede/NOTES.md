# alte_schmiede

- url: https://alte-schmiede.at/programm (Literaturwerkstatt only; Musikwerkstatt
  is a separate section, not scraped — group covers "readings").
- method: html. `/programm` has a "two-months" sidebar block listing every
  upcoming reading as `<a href="//alte-schmiede.at/programm/recital/<slug>">`
  — no pagination needed, it already holds the full near-term list (26 on
  2026-08-08). Each `/programm/recital/<slug>` detail page carries
  `date-test="YYYY-MM-DD HH:MM:SS"` on the `.event-date` div, giving an exact
  start with no year-guessing. Title = `h1.event-title`, category =
  `h3.event-hashtag` (series name, often empty), description = joined
  `.event-artist-info` / `.event-artist-bio` blocks.
- Site publishes only ~2.5 months ahead currently (through end of Oct 2026),
  far short of the 180d default horizon — that's just how far they plan.
- No price info anywhere on the site → price_min/price_text always null.
- Single venue, hardcoded: Schönlaterngasse 9, 1010 Wien.
- Re-derive: refetch `/programm`, confirm `recitals-entry two-months` class
  still present in the sidebar; if the detail page loses `date-test`, fall
  back to parsing `.event-date` text ("Montag, 14. September") +
  `.event-short-date` time with `ea.de_date`, using the current year as
  default (site doesn't cross a year boundary in its published window).
