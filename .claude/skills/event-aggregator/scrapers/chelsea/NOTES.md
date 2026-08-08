# chelsea

- url: https://chelsea.co.at/concerts.php — single flat HTML page listing
  every upcoming concert (49 seen: Aug 2026 through 17 Apr 2027), no
  pagination, no JSON/LD.
- method: html. Each event is `<a name="concert_ID"></a>` followed by a
  `<table class="termindetails">` with `.date`, `.band .highlight`,
  `.price`, `.text` divs. Dates are `DD.MM.` (no year) except where the
  site breaks the sequence far out, where it adds `.YYYY`; year is
  inferred by rolling forward whenever a bare date would go backwards.
- price is free text `VVK: X,XX/AK: Y,-` (advance/door price); price_min
  = the VVK number, `0.0` when the div literally says "Eintritt frei!".
  ea.price() doesn't match this €-less format so parsing is custom.
- category: not published anywhere on the site -> always null.
- venue/address/district hardcoded: single venue, Lerchenfelder Gürtel
  U-Bahnbögen 29-30, 1080 Wien.
- clubs.php exists too (weekly DJ residencies per weekday) but has no
  concrete dates anywhere, so it's not scraped — would require guessing
  which Friday a residency runs.
- site publishes ~250 days ahead; horizon_days set to 270 to capture all.
- breaks if: the `<a name="concert_ID">` / `termindetails` markup or the
  `VVK:`/`AK:` price format changes.
- re-derive: refetch concerts.php, diff div class names and date/price
  regex against a fresh block.
