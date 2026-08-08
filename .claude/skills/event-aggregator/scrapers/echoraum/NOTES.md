# echoraum

- url: https://www.echoraum.at/programm/ — single flat HTML page listing all
  upcoming events (14 real events seen, plus a dateless "Sommerpause"
  placeholder that's skipped), no pagination, no application/ld+json.
- method: html. Each event is `<article class="post-ID ... category-programm
  ...">` with a `.datum` div (`DD. Month YYYY · HH:MM Uhr`), an `<h3><a>`
  title/url, optional `.untertitel` h4, and a `.mitwirkende` div (lineup) used
  as description. `category` = the site's other `category-*` classes on the
  article (e.g. "konzert", "ausstellung, konzert"), joined; "programm" and
  "ohne-details" are excluded as non-categories.
- WP REST API (`wp-json/wp/v2/posts?categories=4`) exists and its `date`
  field is genuinely the event date/time (confirmed against the HTML), but
  it only returns already-published (i.e. past) posts — future events are
  `post_status=future` and 401 when queried directly, so the API is
  useless for scraping upcoming events.
- No price is published anywhere on the site (listing or detail pages), so
  price_min/price_text are always null.
- venue/address/district hardcoded: single venue, Sechshauser Straße 66,
  1150 Wien.
- site publishes through ~end of October 2026 (~80 days ahead of today);
  horizon_days left at 90.
- breaks if: `class="datum"` / `class="mitwirkende"` / the `category-*`
  class naming on `<article>` changes.
- re-derive: refetch /programm/, diff the article/datum/mitwirkende markup.
