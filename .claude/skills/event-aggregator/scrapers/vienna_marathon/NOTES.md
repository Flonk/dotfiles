# vienna_marathon

- URL scraped: https://www.vienna-marathon.com/?go=events (plain server HTML, no ld+json/API)
- Method: html. Parse `<div class="row nomargin">` sections; header `<h4 class="center space-40">`
  gives the day's date. Within each section, split on `card h-100 boxshadow`, strip HTML
  comments, take a card only if it contains a live (uncommented) `registration_options` link -
  that's the only reliable signal for "this race is actually confirmed for next year".
- Card `<small>` dates and titles for non-open races are stale (still say last year), and their
  registration link is commented out / replaced by a disabled "Weitere Infos folgen" anchor, so
  they're skipped rather than guessed.
- Price: fetch each race's own `?go=<slug>` detail page, grab the `Teilnahmebeitrag` `<ul>` block,
  run through `ea.price()` (min of listed options).
- Horizon: site only confirms ~8 months out (next edition April 2027, checked Aug 2026); Saturday
  races (5K, Daily Mile, Inclusion Run) aren't dated yet ("opens registration in September").
  Re-check after that announcement if more races should appear.
- Re-derive: if this breaks, check whether `?go=events` still has the same
  `row nomargin` / `bewerbegrid` / `card h-100 boxshadow` structure, and whether
  `registration_options` is still the marker for "confirmed".
