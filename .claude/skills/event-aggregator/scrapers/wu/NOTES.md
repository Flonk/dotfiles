# WU Wien

- URL: https://www.wu.ac.at/universitaet/news-und-events/events
- Method: html. Listing page is server-rendered TYPO3, no JSON-LD, no working
  RSS/Atom (`?type=9818/9819` both error). No pagination link either — the
  page just contains every upcoming public event (currently ~8, spanning
  May-Oct 2026). Items are `<div data-id="ID" class="item">` blocks.
- Detail enrichment: each card's "Mehr erfahren" click fetches
  `https://www.wu.ac.at/?type=9901&tx_news_pi1[news]={id}` (JSON: dates,
  location, tags/category, description, buttons incl. external/detail url).
  Template comes from `window.eventCardData.url` in the page `<script>`.
- Re-derive: if the detail JSON shape changes, re-click an event card in a
  browser and watch the network tab for the `type=9901` request, or grep
  page.html for `eventCardData`.
- Site only publishes ~5 months out; nothing suggests it goes further, so
  horizon pagination logic isn't needed — we just take everything listed.
- Breaks if: WU changes the `item`/`schedule` markup, drops the
  `eventCardData` JS var, or the `type=9901` detail endpoint moves.
