# breitenseer

- url: https://breitenseer-lichtspiele.at/ — homepage server-renders the
  entire upcoming program as a flat list, no JS fetch, no pagination.
- method: html. Each showtime is `<a href=".../event/<slug>" title="..."
  class="grid justify-center grid-cols-6 ...">` containing a
  `tracking-wider` date/time span (`Di, 11.08.2026 | 00:00 Uhr`), a
  `font-bold pt-2` film title span, and an optional
  `prose prose-slate mt-4` description div (director/country/year/runtime
  or "deutsche Fassung" note).
- source_id: slug from the `/event/<slug>` url (site appends `-2`, `-3`...
  for repeat screenings of the same film, so it's unique per showtime).
- 9 rows titled "geschlossen" + 1 "SOMMERPAUSE BIS 12. AUGUST" are closure
  placeholders (always `00:00 Uhr`) — filtered out, not real events.
- category: site has no genre/label field anywhere, always null.
- price: never published per-event (only a general /preise page with flat
  door prices, not tied to specific screenings) — price_min/price_text
  always null by design.
- venue/address/district hardcoded (single venue): Breitenseer
  Lichtspiele, Breitenseer Straße 21, 1140 Wien (from /kontakt).
- horizon: as of build, page lists ~77 showtimes out to 1 Nov 2026 (~81
  days ahead) — matches the pre-set horizon_days of 90.
- breaks if: the `grid justify-center grid-cols-6` card markup, the
  `tracking-wider` date span, or the `font-bold pt-2` title span classes
  change (Filament/Livewire-generated markup, could shift on a site
  redesign).
- re-derive: view-source the homepage and find the repeating `<a
  href="/event/...">` blocks under the `divide-y divide-gray-300` list.
