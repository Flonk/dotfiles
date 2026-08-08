# kreisky

- url: https://www.kreisky-forum.org/veranstaltungen/
- method: html (server-rendered, no JS/API needed)
- Upcoming events are pre-rendered inside the container marked
  `data-container="events-list" data-view="list"`, each event wrapped in
  `<div id="YYYY-MM-DD">...</div>`. A second container with
  `data-view="archive"` holds past events (73-page AJAX pagination via
  admin-ajax action `kreisky_filter_events`) — not used.
- Fields: title/url from `data-template="title-link"`, time from
  `<span class="ct-span">HH:MM Uhr</span>`, category from
  `data-template="tax-format"` (e.g. "Podiumsdiskussion"), thematic focus
  from `data-template="tax-schwerpunkt"` kept in `extra.schwerpunkt`,
  description from `data-template="event-persons"`.
- Site only publishes ~2 months ahead (currently Sep-Oct 2026, 8 events).
  No price info anywhere; price_min/price_text always null.
- Re-derive: view page source of the events page, search for
  `data-container="events-list"`.
