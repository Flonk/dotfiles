# porgy

- url: https://www.porgy.at/events/upcoming — single page lists ALL upcoming
  occurrences (Aug 2026 - Jun 2027 seen), no pagination needed.
- method: html. No JSON-LD, no XHR endpoint. Rows are
  `<div class="row event_list [more_items]">` blocks; date only appears on
  the first row of each day, carry it forward for subsequent rows.
- price lives only on detail pages (`/events/<id>/`), inside
  `<div class="tickets">...</div>` — one fetch per event. Detail pages also
  contain a commented-out `<!-- ... 0,00 EUR ... -->` stale member-price
  li that must be stripped before price parsing or it corrupts price_min.
- price_min is the minimum of ALL published tiers including the discounted
  "Members" price, since ea.price() just scans €/EUR in the block. Pure
  "Pay as you wish" tiers have no number -> price_min null (correct, not a
  guess).
- venue is hardcoded (single-venue club): Porgy & Bess, Riemergasse 11,
  1010 Wien (confirmed via /page/kontakt/, not on event pages). Ten events
  are in the small side room "In der Strengen Kammer" (stage id 1), tagged
  in venue as "Porgy & Bess – In der Strengen Kammer".
- category = the "zyklus"/"series" label shown per row (festival or
  concert-series name, e.g. "Live & Stream"), null when a show has none.
- breaks if: the site drops the `class="row event_list` row markup, moves
  price out of `.tickets`, or splits /events/upcoming across pages.
- re-derive: re-fetch /events/upcoming, diff row HTML structure, re-check
  one detail page's tickets div for the comment-stripping still needed.
- end/duration: investigated 2026-08-08. No text duration anywhere on site.
  `/events/export/calendar/<id>.ics` has DTEND, but checked 30+ ids across
  all start-time slots (11:00 matinee through 22:00 late show) and every
  single one is exactly DTSTART+2h00m, with no variation by genre/venue/
  room. That's a CMS-wide default, not a real published end time -
  deliberately NOT used. `end` stays null for all porgy records.
