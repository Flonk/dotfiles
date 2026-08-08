# hofburg

- url: https://www.hofburg-wien.at/ -> 301s to https://www.sisimuseum-hofburg.at/
  events page: https://www.hofburg-wien.at/fuehrungen/termine (301 -> sisimuseum-hofburg.at,
  language-detected redirect to /en/... unless Accept-Language: de is sent).
- method: html, microdata `itemtype="http://schema.org/Event"` teaser blocks. No JSON-LD,
  no JSON endpoint found (checked category filters, pagination, month slider - all render
  server-side to the same single teaser).
- This "events calendar" (TYPO3 tx_feventcalendar plugin) currently only contains ONE entry:
  the standing "Sisi Museum und Kaiserappartements" guided-tour admission, dated
  2025-12-01..2026-10-05 (their own explicit season dates, not open-ended - kept as-is,
  not treated as `extra.permanent`). Checked all 3 category filters (Children & Family,
  Guided Tour, Special Guided Tour) and page 2 - same single record every time.
- Site publishes exactly this one far-dated record; no real pagination/horizon to speak of.
- scrape.py splits page.html on the teaser-item marker so it picks up more events
  automatically if the site ever adds any (untested since only 1 exists).
- Re-derive: curl the /fuehrungen/termine URL with Accept-Language: de-AT,de and look for
  `itemtype="http://schema.org/Event"` blocks; grab itemprop meta tags (name/description/
  startDate/endDate/address/url) plus the `.tag-box` category and `.icon-price` fact-item.
