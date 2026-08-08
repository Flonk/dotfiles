# meetup_wien

- robots.txt: no ClaudeBot-specific rule, no blanket disallow, but `Disallow: /*?location=*`
  covers the brief's `find/?location=at--Vienna` URL. Used the path-based
  `https://www.meetup.com/cities/at/vienna/` instead — allowed, and it SSRs the same event
  data via an embedded `__NEXT_DATA__` script (Next.js pageProps), so no disallowed
  `/gql*` or `/mu_api/` calls needed.
- Method: api (parses the JSON blob in `__NEXT_DATA__`, not the page's `application/ld+json`,
  since NEXT_DATA also carries feeSettings/venue/photo that the JSON-LD lacks). pageProps has
  several overlapping curated lists (`eventsInLocation`, `todayEvents`, `thisWeekendEvents`,
  `topicalEvents*`); scraper unions every list whose items are `__typename: "Event"` and dedupes
  by id, one record per event (no recurrence expansion — each Meetup listing is already a
  single dated occurrence).
- Publishes only ~4 weeks ahead server-side (no deeper pagination without the disallowed GraphQL
  API) — well short of the 180-day horizon; this is the ceiling of what's honestly available.
- Breaks if: Next.js stops embedding `__NEXT_DATA__`, or the pageProps key names change.
  Re-derive by curling the city page and grepping for `__NEXT_DATA__`.
- category intentionally left null: the only per-event "category" signal is which curated
  homepage bucket (Music/Social/Outdoor/Sports) it happened to land in, not a real per-event
  label the site assigns, so surfacing it would misrepresent it as genuine site taxonomy.
