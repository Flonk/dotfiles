# bestattungsmuseum

- url: https://www.bestattungsmuseum.at/ (Liferay CMS, static, no JS needed)
- method: html. No JSON-LD, no XHR event feed. This is a tiny permanent museum
  with a single static special exhibition (no published dates anywhere) plus
  two ticketed occurrence types sold via a separate JTL shop (shop.bestattungsmuseum.at):
  1. "Öffentliche Führung" (public guided tour, ~monthly Saturday): date comes
     from the shop tickets category page → its "Ticket für eine Führung..." link
     → `data-option-date` attrs in the product's date configurator.
  2. "Sondervortrag: Scheintot" lecture: dates parsed from the literal
     "Termine: 21.2., 28.3., 18.7., 19.9." line on /fuehrungen; price/confirmation
     pulled from the shop's canonical product page (stable URL, unlike the
     Führung product whose bare canonical URL 404s).
- Site publishes only 1-4 dates total per ticket type, often already stale/past
  by the time you fetch (shop keeps old variants around) — script filters to
  today..horizon. Expect only 1-2 live records at any time; that's real, not a bug.
- Breaks if: /fuehrungen loses the "Termine:"/"regulär"/"ermäßigt" wording, or
  the shop's tickets category page stops linking a "Ticket-fuer-eine-Fuehrung"
  product, or JTL shop markup (`data-option-date`, `itemprop="price"`) changes.
- Re-derive: view-source the /fuehrungen page and the two shop.bestattungsmuseum.at
  product pages linked from it / from kategorie/tickets/.
