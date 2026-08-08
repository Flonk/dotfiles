# burgtheater

- url: https://www.burgtheater.at/spielplan
- method: html (server-rendered Drupal, no ld+json, no JSON endpoint found)
- Listing is paginated by month via `?date=YYYY-MM` ("Nächster Monat" link). scrape.py
  walks from the current month through `ea.horizon()` fetching one page per month; each
  page contains the full month's `<section class="s-event ...">` blocks, no further
  paging needed within a month.
- Each `<section>` is one performance (date + time), covering Burgtheater, Akademietheater,
  Kasino, Vestibül and a few one-off spaces (mapped via VENUE_DISTRICT; unknown venues get
  district null). These are individual showings, not exhibitions, so `end` is always null.
- category/description are rarely present (only badges like "Premiere"/"Uraufführung" or an
  occasional subtitle) — left null otherwise per instructions rather than guessing.
- Price is never shown in the listing (only ticket promo tags like "Ö1: 30%"), so
  price_min/price_text are always null.
- As of build time (2026-08), the site had populated showings through mid-December 2026;
  further months exist as navigable links but return few/no events until closer to the date
  — normal for a theatre that plans a season at a time.
- Breaks if: the `s-event`/`field--name-*` class names change, or the `?date=` query param
  scheme changes.
