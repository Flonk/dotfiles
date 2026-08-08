# wko

- url: https://www.wko.at/veranstaltungen (landing page, JS-only, no data).
  Real listing: https://www.wko.at/veranstaltungen/kalender, driven by
  `POST https://www.wko.at/api/event/filter` (found in wkoui.*.js, function `X`).
- method: api. Body: `{"count":200,"offsetCurrent":N,"aktuelle":true,
  "place":"Österreich","withStorniert":false,"withAusgebucht":false,
  "withAbgeschlossen":false,"von":"","bis":"","veranstaltungstyp":"",
  "zielgruppe":"","kategorie":""}`. Response `{elements:[...html cards...],
  totalCount}`. No auth/cookies required. `von`/`bis` filters appeared to have
  no effect when tested, so pagination just walks `offsetCurrent` until it
  reaches `totalCount` (~1865 total, ~10 requests at count=200).
- Each element is one server-rendered `<div class="card card-event"
  data-gtm-item-id=... data-gtm-item-url=...>` card: title, one date span
  (3 shapes: `DD. Mon. YYYY, HH:MM Uhr` / `DD. Mon. YYYY – DD. Mon. YYYY` /
  `DD. Mon. YYYY`), and one location span (`<icon-pin> PLZ City`,
  `<icon-video> Online`, or nothing).
- Nationwide, not Vienna-only (matches `aurena` precedent). `parse_pin_text`
  reads the pin-icon string generically: `<PLZ> <City>` (AT or foreign,
  any punctuation in the code), a bare city name, or a filtered placeholder
  (`- -`, `MS Teams`, a lone federal-state name) -> district only set when
  the PLZ is a plain 4-digit Austrian one in 1010-1230; city fills for AT
  and foreign in ~67% of records total.
- Detail-page enrichment (`enrich()`, 8 threads, 4 retries w/ backoff):
  fetched only for records the card left ambiguous - no location tag at
  all (~23%, mostly foreign trade-fair listings) or a resolved Vienna
  district (~11%, whose card text never carries a street). Pulls venue
  name + `PostalAddress` (street/postal/locality) from the ld+json. This
  is the only source of `address`, so it's Vienna-only (~11% fill) -
  WKO never structures a street for non-AT events, only free venue prose
  ("JIExpo Kemayoran, Jakarta"), which is intentionally NOT parsed into
  city (too easy to mistake an institution/venue name for a town).
  wko.at 429s detail-page bursts above ~10-15 req/s sustained; scoping
  fetches to the ~450 ambiguous records instead of all 1800 keeps the
  run under the limiter (whole run ~30s).
- category and price_min: not present on the list card, and not worth an
  extra detail fetch per record just for those -> always null.
- Dataset naturally caps around May 2027 (~9 months out), well past the
  180d EA_HORIZON_DAYS default, so horizon isn't actually a limiting
  factor here - full dataset is fetched every run.
- Breaks if: `/api/event/filter` changes shape, the `card card-event`
  markup or `data-gtm-item-id`/`data-gtm-item-url` attrs disappear, or the
  date-span text format changes.
- Re-derive: view-source the `/veranstaltungen/kalender` page's JS bundle
  (`wkoui.*.js`) for the `/api/event/filter` POST body shape and `X(...)`
  function, or just diff a `curl -X POST` response against a card in the
  page HTML.
