# hausdermusik

- url: https://www.hdm.at/ (redirects from hausdermusik.com). No JSON-LD Event data,
  and no special/temporary exhibition anywhere on the site right now — the museum is
  permanent and not itself modelled as an event. The only real event data is the
  `/konzerte/` "Klassik Cool" concert series (kids concerts + occasional "Live On Stage").
- method: html. Listing at `/konzerte/` is a JetSmartFilters/Elementor grid
  (`jet-listing-dynamic-post-<id>` blocks), 6 items/page, sorted ascending by date.
  Paginate with the pretty URL `/konzerte/jsf/jet-engine:konzert-loop/pagenum/<n>/`
  (found this by grepping `valid_url_params` in the page's inline JetSmartFilterSettings
  JSON — `pagenum` works, `paged`/`jet_paged` don't). Stop once a page's date exceeds
  `ea.horizon()`. Each concert's own detail page has an "Eventdetails" block
  (`Datum:`/`Beginn:`/`Eintritt:`/`Bühne:`) which is fetched per record for price/venue;
  description comes from the `theme-post-content` widget.
- Site publishes ~93 upcoming concerts total, out to ~June 2027 (~10 months ahead) —
  far past the 180-day horizon default, so pagination is bounded by horizon not by site.
- Breaks if: the `jet-listing-dynamic-post-` / `dce-term-item` classes change, the
  `pagenum` pretty-URL alias is removed, or the `Eventdetails` labels (Datum/Beginn/
  Eintritt/Bühne) change. Re-derive by curling `/konzerte/` with a browser UA and
  grepping for `JetSmartFilterSettings` to rediscover `valid_url_params`.
- ~65 detail-page fetches per run; the site occasionally times out on rapid sequential
  requests, so scrape.py retries each fetch (4 tries, backoff) — a bare `ea.fetch` was
  seen to fail intermittently under check.py.
