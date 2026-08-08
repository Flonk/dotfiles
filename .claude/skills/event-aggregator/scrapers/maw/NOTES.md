# maw

- url: https://www.maw.co.at/de/kongresskalender
- method: html. One static page, no JS/XHR needed. Every congress is a
  `<div class="panel panel-default" ...>` accordion item; all ~96 upcoming
  congresses are rendered server-side on one request (site publishes as far
  ahead as it likes — currently through Oct 2027, no pagination to chase).
- Date line is `<span class="subline">DATE | City, Country</span>`, mixed
  German ("4. - 5. September 2026") and English ("September 3 - 6, 2026" /
  "June 30 - July 3, 2027" for cross-month) formats — both handled.
- source_id = the ics filename stem (e.g. ANATOMIE26), fallback to logo
  filename, fallback to title.
- No price info anywhere on the site → price_min/price_text always null.
- No category/Fachgebiet field on the site → category always null.
- Venue/address/city parsed from the "Veranstaltungsort" row
  (`Name, Street<br>ZIP City, Country`); occasionally the site itself
  omits the ZIP/city (e.g. LIPIDMGMT26) — city/district come back null
  there rather than guessed.
- Re-derive: refetch the URL, look for `class="panel panel-default"` and
  `class="subline"` structure; if MAW redesigns the accordion this parser
  breaks entirely.
