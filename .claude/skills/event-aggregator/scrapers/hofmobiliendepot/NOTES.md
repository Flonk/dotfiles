# hofmobiliendepot

- url: https://www.hofmobiliendepot.at/ redirects to https://www.moebelmuseumwien.at/en/
- scrape.py fetches https://www.moebelmuseumwien.at/en/program/events (English-only site,
  /de/ 404s). That page lists exhibitions, events and guided tours together as
  schema.org/Event microdata "teaser-item" blocks (name/description/startDate/endDate/
  address via itemprop meta tags, category from a `.tag-box span`, detail link from the
  "learn more" button href).
- Site currently only publishes ONE item: the running special exhibition "MADE IN AUSTRIA"
  (2026-04-15 to 2026-12-08). The events page has category filter checkboxes (Exhibition,
  Event, Guided Tour) and a month-range date filter, but querying them via plain GET curl
  returned the same single result each time — either JS-driven or genuinely nothing else
  scheduled. /program/exhibitions and /program/events render the identical teaser block.
- Breaks if: TYPO3 template renames the `teaser-item`/`schema.org/Event` microdata classes,
  or the "learn more" button markup changes (detail URL is read from that anchor, not from
  the itemprop=url meta which points at a slightly different, also-working path).
- Re-derive: curl the events URL with a browser UA, diff against this file's regexes.
