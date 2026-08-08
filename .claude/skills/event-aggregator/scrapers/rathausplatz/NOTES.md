# rathausplatz

- url: https://filmfestival-rathausplatz.at/, method: api (The Events Calendar / tribe plugin REST API)
- Homepage and /programm/ HTML only embed ld+json Event data for the current ~week
  (rolling widget), not the whole festival. Use
  `/wp-json/tribe/events/v1/events?per_page=50&page=N` instead — no auth, paginate
  via `total_pages`. 45 events found for the 2026 run: Aug 8 - Sep 6, one evening
  screening (sometimes two back-to-back) per day at Rathausplatz.
- `cost` in the API is always `""`. FAQ page (/faq/) states entry is free in plain
  text, so price_min is hardcoded 0.0 / "Eintritt frei" rather than parsed per event.
- `category` = the API's `custom_fields` entry whose label starts with "Genre"
  (Oper, Pop, Klassik, Austropop, Jazz, Kurzfilm, ...), verbatim.
- venue/district/address hardcoded to Rathausplatz, 1010 Wien; do not confuse with
  the custom field "Aufführungsort" (recording location of the film, e.g. "Wiener
  Staatsoper" or "Donauinsel, Wien" — kept out of the record, only in description).
- Site only publishes one festival run per year, ~4 weeks long, so pagination
  beyond page 1 rarely matters; EA_HORIZON_DAYS is moot here.
- Re-derive: fetch https://filmfestival-rathausplatz.at/wp-json/tribe/events/v1/events?per_page=50
  directly; confirm `custom_fields` still carries a "Genre:" label.
