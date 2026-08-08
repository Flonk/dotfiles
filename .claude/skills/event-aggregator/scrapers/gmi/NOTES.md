# gmi

- url: https://www.gmi.oeaw.ac.at/news-events (301s to a bare /gmi hub) ->
  actually scraped: https://www.oeaw.ac.at/gmi/news-events/events
- method: html. Same TYPO3/Cloudflare backend as scrapers/imba (GMI is an
  ÖAW institute like IMBA), but www.gmi.oeaw.ac.at's own reverse proxy only
  forwards a subset of paths correctly - `/detail/event/*` and
  `/news-events/calendar-details` return a generic homepage on that
  domain, so all fetches go through `https://www.oeaw.ac.at/gmi/...`
  directly (unlike imba, no prefix-stripping needed/possible here).
- Cloudflare intermittently 403s ~20-30% of requests even for a plain
  HTTP/1.1 browser UA; every fetch retries up to 10x with backoff (~1
  minute total runtime, well under check.py's 300s budget).
- Discovery: mini-calendar widget, walked month by month via each page's
  own "next" link (carries a live TYPO3 cHash - arbitrary month/year query
  strings 404). Per-event detail page gives the authoritative
  "Date/Time/Speaker/Location/Type/Institute/Host" line.
- Same shared IMP/IMBA/GMI VBC seminar programme as scrapers/imp and
  scrapers/imba (identical events, different site ids) - expected overlap.
- Publishes ~6 months out (Aug 2026 - early Feb 2027 seen at build time).
- Re-derive: view-source www.oeaw.ac.at/gmi/news-events/events for
  `events-mini-list` and the `class="next"` calendar link.
