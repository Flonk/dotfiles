# hgm

- URL: https://www.hgm.at/events — server-rendered TYPO3 (sf_event_mgt) event list, single fetch, no pagination markup found (all 30 upcoming events on one page).
- Method: html. Cards split on `<div class="col-12 col-md-6 col-lg-4 mb-3">`; each has a venue badge (`bg-secondary-20`, one of HGM/Panzerhalle/Heldenplatz/Korneuburg — hardcoded to venue/district/city), a price badge ("Kostenfrei" or "X Euro"), a `<time>` with `DD / MM / YYYY` + optional time range, `<h3 class="card-title">` and a `<p class="mt-2">` description.
- No genuine event category on the site (the badge is a location tag, reused here as venue) — `category` is always null.
- Site publishes ~2 months ahead (through mid-Oct 2026 as of this build); horizon isn't really exercised since there's no pagination to walk further.
- `end` always null (single-session events, no listed end time separate from start).
- Korneuburg events are outside Vienna (Patrouillenboot-Staffel cooperation site) — district null, city "Korneuburg".
- Re-derive: if `section-event-list` / `col-12 col-md-6 col-lg-4 mb-3` / `card-title` markup changes, re-inspect a fresh fetch of /events.
