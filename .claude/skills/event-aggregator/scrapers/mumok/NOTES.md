# mumok

- url: https://www.mumok.at/de/ausstellungen (307-redirects to /ausstellungen/aktuell)
- method: html — no JSON-LD or API; server-rendered `teaserbox exhib` blocks parsed
  with regex for the `exhib-overline` date range ("D. Month YYYY bis D. Month YYYY"),
  `title`, and detail-page href.
- Also fetches /ausstellungen/vorschau (upcoming) to catch exhibitions not yet open.
  /ausstellungen/rueckblick (past) is intentionally skipped.
- Site only ever lists ~2 current + ~2 upcoming exhibitions (whatever is scheduled
  months/a year ahead) — no pagination, publishes as far as their own program planning goes.
- Fixed venue: mumok, Museumsplatz 1, 1070 Wien.
- No ticket-price text found anywhere on listing/detail pages, so price_min/price_text
  are always null (never guessed).
- Breaks if: TYPO3 template renames `teaserbox exhib` / `exhib-overline` / `title` /
  `cta-button` classes, or German month names change.
- Re-derive: curl the two listing pages, grep for `teaserbox exhib`.
