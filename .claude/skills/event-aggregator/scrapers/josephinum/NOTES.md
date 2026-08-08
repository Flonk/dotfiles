# josephinum

- url: https://www.josephinum.ac.at/
- method: html (no JSON API, no JSON-LD)
- Events: `/veranstaltungen/?ed=YYYY-MM` is a server-rendered monthly calendar, mostly
  "Keine Veranstaltungen gefunden". scrape.py walks months from today through
  `ea.horizon()`. Site currently only publishes 1 real event that far out.
- Exhibitions: `/aktuelle-ausstellungen/` has a swiper slider with 4 slides (2 dated
  special exhibitions + Dauerausstellung + Seligmann-Fragmente). Dated ones whose
  end < today are dropped (site had 2 stale/expired entries at scrape time). The
  other two are open-ended -> `extra.permanent: true`, `end: null`. Dauerausstellung
  has no stated start anywhere on site, so `start` = today (matches convention used
  by freud_museum/hdgoe scrapers).
- No prices published anywhere -> price_min/price_text always null.
- Re-derive: if class names `event-item` / `date-wrapper` / `title h4` change, or the
  `?ed=` query param stops working, the regexes in scrape.py will need rework.
