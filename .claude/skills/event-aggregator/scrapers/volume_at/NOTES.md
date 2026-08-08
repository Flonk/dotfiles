# volume_at

- url: https://www.volume.at/events/ (list index); actual pagination via
  https://www.volume.at/events/<YYYY-MM-DD>/, server-rendered, no JS needed.
- method: html. No JSON-LD, no XHR endpoint found. Each fetch renders a
  window of ~4-7 upcoming days (varies), grouped under
  `<span class="day">.. <span class="weekday">.. <span class="month">..`
  headers followed by `<article ... item--event data-content-id="...">`
  cards. Dates with zero events are skipped entirely in the markup, so the
  scraper advances the request cursor to `max(dates seen) + 1 day` each
  loop instead of assuming a fixed window size.
- fields: title/url/category (item__eventtype)/venue/price
  (item__offers, "VVK €X AK €Y" / "Gratis Eintritt!") all on the listing
  card — no per-event detail fetch needed. No event time and no street
  address, only a bare city/town name (`location__address`), so `district`
  is always null and `city` is only set to "Wien" when that text is
  literally "Wien".
- cancellation: a literal `abgesagt` badge inside the title link. The
  `item__title--canceled` CSS class is present on every single card
  regardless of status — do not use it as a signal (looks like a red
  herring / generic class name).
- horizon: site actually publishes real listings out to ~Feb 2027 (~6
  months), density tapers off from ~7-10/day near-term to a handful/month
  far out. horizon_days=180 takes ~35s / ~25 requests and yields ~1300
  records.
- breaks if: the `item--event` / `result__date` markup or class names
  change, or the per-day URL scheme changes.
- re-derive: curl a day URL, diff the `<article class="... item--event"`
  block structure and the `abgesagt` badge markup.
