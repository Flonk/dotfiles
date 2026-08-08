# belvedere

- URL: https://www.belvedere.at/ausstellungen (301s to /ausstellungen-aktuell). Fetch once, no pagination — the page lists all currently running exhibitions (8: 2 permanent, 6 temporary), no infinite scroll pages beyond what's rendered.
- Method: html. The page's `application/ld+json` (`@graph`/`ItemList`) only has titles + links, no dates — parsed server-rendered `<article data-history-node-id>` teaser cards instead (class `teaser__node-exposition`), each with `content__header__element` (category + venue), `<h3><span>title</span>`, subtitle `<p class="...text-black...">`, and a `<time datetime="ISO">` pair for start/end.
- "Dauerausstellung" (permanent) rows have no `<time>` tags at all — end synthesized as today + 3 years since the schema wants a far end, not null. Site publishes real dates ~2-9 months out per temporary show; horizon isn't really exercised since there's no pagination.
- Venue → district hardcoded (Oberes/Unteres Belvedere, Belvedere 21 are all 1030) since addresses aren't on this page.
- price_min always null — ticket price isn't shown on the listing, only a generic "Tickets" link.
- Re-derive: if `article data-history-node-id` or `content__header__element` class names change, re-inspect a fresh fetch of the URL.
