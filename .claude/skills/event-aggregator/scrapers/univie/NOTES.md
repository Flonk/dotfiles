# univie

- url: https://kalender.univie.ac.at/, method: jsonld (via per-event detail pages)
- No robots.txt (404). Listing `/` is server-rendered (TYPO3 UnivieEvents), 3-6 events
  per page, day-grouped. Pagination follows a `float-right`/"Weiter" link whose `cHash`
  is generated per page+argument combo - you MUST use the href TYPO3 gives you, guessing
  or reusing a cHash from elsewhere 404s/falls back to page 1.
- Each event's `id` -> `/einzelansicht?...id={id}&cHash=...` detail page has a
  `schema.org/Event` JSON-LD block: name/startDate/endDate/location/description/
  isAccessibleForFree/eventStatus. Category (e.g. "Vortrag, Präsentation, Fortbildung",
  "Konferenz, Kongress, Tagung", "Ausstellung") only exists as inline HTML text on the
  detail page, not in the JSON-LD, so it's scraped separately from the same fetch.
- Also scrapes the homepage's "Teaser" (one repeating highlighted event) and the
  "Ausstellungen" sidebar box (long-running exhibitions) for ids that may not appear
  in the day-by-day paginated list.
- price_min is 0.0 only when isAccessibleForFree is literally true; no price field
  exists otherwise, so it stays null (never guessed).
- Site publishes its entire forward calendar (~170 days, to 2027-01-26 at build time)
  before pagination just stops (no more "Weiter" link) - horizon_days=180 comfortably
  covers the whole thing; increasing it further has no effect.
- Re-derive: fetch `/`, confirm `###MAINLIST### begin/end` and `###Teaser###`/
  `###EXHIBITIONBOX###` HTML comments still bound those sections, and that the
  `row bg-gray-lightest p-4 mb-6` event-row div and the JSON-LD `@type":"Event"` block
  on a detail page are unchanged.
