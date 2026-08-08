# filmmuseum

- url: https://www.filmmuseum.at/kinoprogram/sept_okt_2026 (bimonthly
  programme-preview page; homepage links here as "Programmvorschau").
- method: html. As of build date the cinema is closed for Sommerpause
  (through 31 Aug 2026); the daily `/kinoprogrammspielplan` calendar and
  `/kinoprogrammschiene?schienen_id=` detail pages carry no per-film
  showtimes yet, only this teaser page. Site publishes program two months
  at a time, ~1 month ahead of the block starting — so horizon is really
  only what's visible in the current "Sept/Okt 2026" block (~75 days out
  from build date); horizon_days set to 90 accordingly.
- one record per `programm-eintrag` block (= one retrospective/series
  "Schiene", e.g. "Michael Mann", "Aardman Animation"), not per
  screening — individual showtimes aren't published this far out.
  start/end = the block's own date range (`programm-datum` text, parsed
  from German "D. Month bis D. Month YYYY" / "D. und D. Month YYYY" /
  single-date forms). category = the site's own `<h3>` subtitle
  ("In Person", "Collection on Screen", etc.), when present.
- Peter Kubelka's "Was ist Film" cycle runs "Jeden Dienstag" with no
  announced end; bounded here to the Sept-Oct window like everything else.
- price never shown on this page → price_min/price_text always null.
- breaks if: the `programm-eintrag`/`programm-datum`/`schienen_id` HTML
  structure changes, or the URL slug for the next season's preview page
  changes (re-derive from the homepage "Programmvorschau" link).
- image: the listing's own `programm-image` span has no `<img>` (JS/CSS
  populated). Each schiene detail page (`/kinoprogramm/schiene?
  schienen_id=...`, same URL already used as `url`) has a real still as
  its first `/jart/prj3/filmmuseum/images/cache/...jpeg` `<img>` — its
  own `og:image` meta tag is the site logo, deliberately not used.
  Fetched concurrently (8 workers, 3 retries), 19 detail pages, ~1s total.
- no per-record runtime exists anywhere (each record is a whole
  series/retrospective covering many films), so no `extra.duration_min`
  is emitted here — nothing to derive an end date from beyond the
  series' own published date range, which is already `end`.
