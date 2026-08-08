# gartenbaukino

- url: https://www.gartenbaukino.at/ (data pulled from
  `/programm/programmuebersicht/`, a single static page that lists both the
  current ("Aktuell") and upcoming ("Vorschau") programme).
- method: jsonld. Each showtime is its own `<script type="application/ld+json">`
  Event block (no pagination needed, all found on one fetch).
- source_id: single screen, so an Event's `startDate` is unique; matched
  against the ticket links (`...PrgID=<id>` anchors wrapping a
  `<time datetime="YYYY-MM-DD HH:MM">`) on the same page to recover the
  site's real booking id. Falls back to `<slug>-<start>` if unmatched.
- price: not in the ld+json. Fetched per movie from the detail page's
  `<b>Tickets</b> * Normalpreis € X.-` / `Einheitspreis ... € X.-` line;
  regex deliberately anchored to that label so it doesn't pick up the
  cheaper "Abo" surcharge prices listed after it. One reading event
  ("AN EVENING WITH FRAN LEBOWITZ") has no price on site → left null.
- category: no genre/category label exists anywhere on the site → always null.
- horizon: overview page itself currently runs through ~2027-03; with the
  default 90-day horizon (per meta schedule) about 46 of the ~59 listed
  showtimes survive the cutoff.
- breaks if: the "Normalpreis"/"Einheitspreis" wording changes, or the
  PrgID/time markup in the ticket links changes shape.
