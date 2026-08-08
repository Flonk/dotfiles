# Volkstheater

- url: https://www.volkstheater.at/spielplan/
- method: api (WordPress admin-ajax, not a public REST route)
- POST https://www.volkstheater.at/101/wp-admin/admin-ajax.php
  body: action=ajax_load_events&start_date=<unix ts midnight>&end_date=<unix ts +30d>&load_future_events=true&jump_date=
  returns JSON {events: "<html fragment of <article> blocks>", end_date, has_future, ...}.
  Loop: reuse returned end_date as next end_date, stop when has_future is falsy (site itself
  runs out of data, not our horizon) or once past EA_HORIZON_DAYS.
- Each <article id="event-N" data-time="unix ts"> is one occurrence; data-time is exact
  local start incl. time, no separate date/time parsing needed.
- Site is dark for summer, so "today" queries jump straight to the first Sept event -
  no manual past-event filtering needed. Real listing runs to ~May 2027 (~9 months out).
- price_min from the `.price-info` div only. The `.ticket-col` sometimes says
  "Tickets ab 7.9.2026" (presale date, no price) - including that text in price parsing
  made a date get mistaken for a price; only used for detecting "Eintritt frei".
- category ("Premiere", "Wiederaufnahme", "Kabarett", "Lesung", ...) verbatim, sparse.
- district derived from venue text: main venues (Volkstheater/Rote Bar/Dunkelkammer/
  Weißer Salon) hardcoded to 1070; "Volkstheater Bezirke" satellite venues carry
  "N. Bez." in their name, parsed to 1000+N*10.
