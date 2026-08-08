# japannual

- url: https://www.japannual.at/ (Wix site)
- method: html — regex over `ea.text()` of the homepage, no JSON/ld+json/API available.
- The full film catalogue with per-screening times only ever exists as an image or a
  downloadable PDF spielplan (`spielplan25`, `/_files/ugd/...pdf`); never as text. The
  "Filme" dynamic-page catalogue is a client-rendered Wix list, empty in raw HTML until
  JS runs. So this scraper does NOT enumerate individual films/showtimes — it emits one
  record for the whole festival week (start/end = the announced dates), like a
  months-long exhibition would be one record.
- Regex parses: "von D. bis D. Month YYYY" for dates, "FILMCASINO <address> 1050 WIEN"
  for venue/address, and the "Preise ... Festival Pass: € N,-" block for price (min of
  all € amounts found via `ea.price`).
- Publishes ~1 edition at a time, dates/pricing appear announced a few months ahead
  (2026 edition, Oct 8-15, already up in August). Re-derive by re-fetching the homepage
  and checking these three regexes still match; if the site redesigns the banner wording
  the date regex is the most likely thing to break.
- If a future edition's dates aren't announced yet, no date regex match → scraper emits
  nothing (correct, no fabrication).
