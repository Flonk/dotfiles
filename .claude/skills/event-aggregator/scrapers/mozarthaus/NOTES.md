# mozarthaus

- url: https://www.mozarthausvienna.at/events-2 (single venue: Domgasse 5, 1010 Wien)
- method: html. No ld+json, no JSON API — server-rendered cards.
- Listing pages: `/events-2`, `/events-2/p2`, `/events-2/p3`. Next page exists iff
  the string "Weiter →" appears; p3 is currently the last page (only "← Zurück").
- Card regex pulls `<a href="/news/...">` + `<h2>title</h2>` + `<p>weekday, D. Month YYYY | H.MM Uhr</p>`.
- Category isn't shown on the card. Re-fetch `/events-2?category=X` for each of
  konzert/event/workshop/family-kids/führung (führung URL-encoded), union hrefs
  per category, join labels with ", " (an event can be tagged with several, e.g.
  a kids workshop is both "Event, Workshop, Family & Kids").
- Price + description only live on the detail page (`/news/<slug>`): grab the
  content-text block right after the "Tickets" h1/h4, and the first non-Tickets
  content-text block for description. ~5/46 events have no numeric price on the
  page (concert ticket price bundled elsewhere) → price_min null, correctly.
- Site currently only lists occurrences out to ~early Dec 2026 (~4 months ahead),
  short of the 180d horizon — that's just how far they've published, not a bug.
- Re-derive: if the "Weiter →" marker text or the "Tickets" heading text changes,
  update CARD_RE / TICKETS_RE in scrape.py accordingly.
