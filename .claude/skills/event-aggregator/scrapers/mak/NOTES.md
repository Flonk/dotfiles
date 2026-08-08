# mak

- url: https://www.mak.at/programm
- method: html, two sources combined.
  1. Calendar: form `#kalender-filter` POSTs to
     `/jart/prj3/mak-resp/main.jart?reserve-mode=reserve&content-id=1414100174649&rel=de`
     with `events-limit=300` returns all dated occurrences (guided tours,
     talks, workshops) in one shot as `<article class="kalender-list-entry">`
     blocks, each containing an embedded ld+json Event with a clean ISO
     `startDate`. Category comes from the hidden second line of
     `.entry-date .text-end` (e.g. "Ausstellungsführungen", "Kurz und gut").
     Site publishes ~4 months ahead currently (through Dec 2026).
  2. Exhibitions: `/programm/ausstellungen` index lists slugs; each detail
     page has `.ausstellung-info .date` as `D.M.YYYY&mdash;D.M.YYYY` and
     `.room` for the hall — emitted as one far-end record per exhibition
     (~10 currently, through Jan 2027).
- No price anywhere on site → price_min/price_text always null.
- Venue/district/address hardcoded for the two Vienna addresses (MAK main
  building 1010, Geymüllerschlössel 1180); exhibitions at satellite venues
  outside Vienna (detected by a comma in `.room`, e.g. "Los Angeles,
  Schindler House") get all location fields null instead of guessing 1010.
- Re-derive: refetch `/programm`, confirm `kalender-list-entry` still
  present; if the POST form's `content-id` changes, find the new one in the
  `<form id="kalender-filter" ... action="...">` action URL.
