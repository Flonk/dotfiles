# ottakringerbrauerei

url: https://www.ottakringerbrauerei.at/de/events-locations/eventkalender/
(meta's original /de/events/ 301s to a rental-pitch page with no event data;
the real calendar is under "Eventkalender" in the site nav)

method: html. Server-rendered `<article class="event-calendar-item">` cards,
one per occurrence, no ld+json/XHR, no pagination — everything sits on one
page (~38 upcoming items when scraped). The listing shows day+month+time but
no year, and ordering is not strictly chronological near the end (a "30 Nov"
card sits after a "02 Dez" one, and one far-future card with just "15 März"
is tacked on last), so year can't be inferred by rollover. scrape.py fetches
each item's detail page and reads `event-detail__uptitle` which has the
authoritative "DD.MM.YYYY" or "DD.MM.YYYY - DD.MM.YYYY" string; that's also
where the description paragraph (`event-detail__text copy`) comes from.

Site publishes ~7 months ahead (checked Aug 2026, furthest item was March
2027); horizon_days=180 trims the March item off in practice.

Breaks if: the `event-calendar-item__title`/`event-detail__uptitle` class
names change, or the eventkalender path moves again. Re-derive by curling
the URL above and grepping for `event-calendar-item`.
