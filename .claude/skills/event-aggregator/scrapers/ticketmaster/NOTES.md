# ticketmaster

- url: https://www.ticketmaster.at/discover/wien?page=N (N=1,2,3,...)
- method: jsonld. Each listing page embeds an `application/ld+json` array of
  schema.org Event objects (20 per page), sorted chronologically ascending.
- robots.txt disallows /json/search/*, /api/, /browse, /search.php etc, but
  /discover/wien is not disallowed, so we scrape the rendered HTML directly.
- Pagination stops on an empty page or once a page's last event start date
  passes `ea.horizon()` (meta.json horizon_days=30, so normally only page 1-2
  are fetched; the site itself publishes events out to roughly mid-2027).
- No price or category fields in the listing JSON-LD; a detail-page fetch
  would be needed for those, skipped per instructions. `end` is always null
  (the JSON-LD endDate is just startDate's calendar day, not a real range).
- district derived from location.address.postalCode (Vienna 1xxx only).
- Breaks if: TicketMaster stops embedding ld+json on /discover/wien, or
  changes the pagination query param away from `?page=`.
