# depot

- url: https://www.depot.or.at/programm
- method: api — WordPress site runs The Events Calendar plugin; its public REST
  API at `https://www.depot.or.at/wp-json/tribe/events/v1/events?per_page=50&page=N`
  returns all upcoming events (no auth needed). `total_pages` tells you when to stop.
- The API only ever returns upcoming events (no past events mixed in), and the site
  currently only publishes ~13 events out to about 2.5 months ahead (Sep-Oct 2026) —
  there's no deep horizon to paginate into, `total_pages` was 1 at 50/page.
- All Depot events are free entry ("Eintritt zu allen Veranstaltungen im Depot ist
  frei." on the programm page) and take place at the venue itself, Breite Gasse 3,
  1070 Wien — hardcoded venue/district/address/price_min=0 since the API's own
  `venue`/`cost` fields are empty for every event.
- category = comma-joined verbatim TEC category names (events can have several).
- Re-derive: hit the API URL directly in a browser/curl; if it 404s the plugin was
  removed/renamed and you'd fall back to parsing the `programm` HTML instead.
