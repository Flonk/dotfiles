# esi

- url: https://www.esi.ac.at/events/
- method: html (server-rendered, no JS needed, no ld+json, no API)
- Page has two `<dl class="event-list">` blocks under tabs: `#tab-events`
  (programmes/workshops, multi-day, category = 2nd `.event-item-detail` span)
  and `#tab-talks` (individual talk occurrences with `HH:MM - HH:MM`, grouped
  under `<h2>` date headers, category set to "Talk").
- Dates are English "Month D, YYYY" (events) or "Mon DD. YYYY" (talks) -
  ea.de_date doesn't fit this format so scrape.py has its own tiny parser.
- No pagination: the events list already extends to late 2027 on one fetch;
  the talks list only shows the next handful of days (whatever the site
  currently has scheduled), so far-future talks simply aren't published yet.
- Venue/address (Boltzmanngasse 9, 1090 Wien) pulled from /contact, not on
  the events page itself.
- No pricing info anywhere on site (participation mostly by invitation);
  price_min/price_text left null for every record, never guessed.
- Re-derive: refetch /events/, check that `<dd class="event-item">` and
  `event-item-detail` classes still exist (canary).
