# imba

- url: https://www.imba.oeaw.ac.at/events (redirects to a content-free
  homepage view) -> actually scraped: https://www.imba.oeaw.ac.at/seminars-events
- method: html. Content is served from oeaw.ac.at (TYPO3, `/imba/*` paths)
  behind Cloudflare; imba.oeaw.ac.at just 302s straight through. Links in the
  markup carry the `/imba` prefix even when read via the imba.oeaw.ac.at
  domain, so scrape.py strips it before refetching (`strip_prefix`).
- Cloudflare intermittently 403s ~20-30% of requests even for a plain
  HTTP/1.1 browser UA (no TLS/JS fingerprint issue found, just flaky) -
  every fetch is wrapped in a 10-try backoff retry. A full run takes ~1-2
  minutes because of this, well under check.py's 300s budget.
- Discovery: mini-calendar widget, walked month by month via each page's
  own "next" link (has a live TYPO3 cHash; you cannot construct arbitrary
  month/year query strings yourself, they 404). Per-event detail page then
  gives the authoritative "Date/Time/Speaker/Location/Type/Institute/Host"
  line (list teaser truncates this on busy days).
- Same shared IMP/IMBA/GMI VBC seminar programme as scrapers/imp (same
  events, different site ids) - expected overlap, not a bug.
- Publishes ~6 months out (Aug 2026 - early Feb 2027 seen at build time).
- Re-derive: view-source the seminars-events page for `events-mini-list`
  and the `class="next"` calendar link.
