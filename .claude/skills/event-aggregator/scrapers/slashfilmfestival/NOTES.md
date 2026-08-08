# slashfilmfestival

- url: https://slashfilmfestival.com/ (WordPress, plain server HTML, no ld+json Events,
  no useful REST post types beyond default posts/pages)
- method: html — fetches `/infos/` for the "17. SLASH FILMFESTIVAL 23. September –
  4. Oktober 2026" style date-range blocks (regex `DATE_RANGE_RE`) and the venue list
  (`Spielorte`: Gartenbaukino, Filmcasino, Metro Kinokulturhaus & Festivalzentrum, Club
  Celeste). Fetches the homepage separately for the `»...«` tagline used as description.
- One record per named edition on `/infos/` (main autumn festival + the smaller "SLASH ½"
  mid-year edition), past editions (end date < today) dropped.
- No per-film screenings/times/venues are ever published as text this far ahead — new
  titles trickle in via blog posts (`Programmvorschau #N`) with zero dates attached, so
  this cannot emit per-screening records; one occurrence per festival week only, like a
  months-long exhibition.
- No ticket prices found anywhere on site yet (probably posted closer to the date) —
  price_min/price_text left null, not guessed.
- Re-derive: refetch `/infos/`, check the `Spielorte` venue names and the
  `D. Month – D. Month YYYY` date pattern still hold; refetch `/` for the `»...«` tagline.
