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
- Nationwide, not Vienna-only (matches `aurena` precedent): district only
  set when the PLZ falls in 1010-1230, city set to whatever text follows
  the PLZ otherwise left null (foreign/no-address events).
- category and price_min: not present on the list card at all (only inside
  each detail page's ld+json `Event`, not fetched here to keep request
  count low) -> always null.
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
