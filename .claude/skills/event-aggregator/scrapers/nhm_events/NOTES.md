# nhm_events

- url: https://www.nhm.at/veranstaltungskalender
- method: html (server-rendered, no JS needed)
- The JS-driven date-nav/pagination just rewrites the querystring and reloads:
  `?datum_von=YYYY-MM-01&dateMode=month&page=N` (20 records/page, param names
  found in an inline `<script>` block on the page, not main.js).
- Each `<div class="grid grid--termin">` is one occurrence (title, date, time
  range, description, venue label). Recurring tours/shows appear as many
  occurrences with the same detail-page slug, matching the schema's "one
  record per occurrence" rule.
- Venue label doubles as the site's own "category" (NHM Wien / Narrenturm /
  occasionally Hallstatt for off-site digs). Mapped Vienna venues to
  address+district; non-Vienna venues (e.g. Hallstatt) get null district.
- No price info anywhere in list or detail pages -> price_min/price_text
  always null.
- Publishes ~3-4 months ahead from "today" (Aug 2026 run: events through late
  Nov 2026, Dec thin, Jan 2027 empty). Scraper stops after 2 consecutive
  empty months, so it self-adjusts if the site's horizon changes.
- Re-derive: refetch the base URL, search inline `<script>` for `datum_von`
  to reconfirm param names if the markup ever moves to real JS/AJAX.
