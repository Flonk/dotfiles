# jmw

- url: https://www.jmw.at/ausstellungen
- method: api. The page's exhibition list is a "jart" Handlebars app
  (`ausstellung_liste`). It POSTs `cmd=filterResults` +
  `data={"aktuell"|"vorschau": "<today>", "customSort":"default","sel-start":0}`
  to `/jart/prj3/jmw/resources/dbcon-def/reports/apps/ausstellung/ausstellung_liste/
  ausstellung_liste.jartc` and gets back `{"record_count": N, "ausstellung": [...]}`
  with clean `datum_von`/`datum_bis` (YYYY-MM-DD), `titel`, `ort_name`,
  `permanent`/`permanent_online` flags, and `j-cc-id`. Scraper calls both the
  "aktuell" and "vorschau" filters and unions by id (dedup); "archiv" (past) is
  ignored.
- Records where `permanent`/`permanent_online` == "ja" get `end: null` and
  `extra.permanent: true` — the site's own `datum_bis` for these (e.g.
  2033-12-31, 2042-01-01) is a fake placeholder, not a real end date.
- Detail url: `/ausstellungen/ausstellung_detail?j-cc-id=<id>&j-cc-name=hybrid-
  content&j-cc-node=ausstellung`; description is scraped from that page's
  `class="detail-text"` div (empty for the two Dauerausstellungen — their real
  text lives in a different block further down the page, not scraped).
- price_min/price_text = the general adult day ticket (EUR 15, "Erwachsene €
  15,-") scraped once from the Preise page (content-id=1595137743227), applied
  to all physical-venue exhibitions (Museum Dorotheergasse, Museum Judenplatz,
  Project Space - Dorotheergasse — all 1010 Wien). The one online-only
  exhibition gets venue/district/price all null (never stated free anywhere).
- Site publishes exhibitions well beyond the 180d horizon (through mid-2028
  already) — scraper doesn't horizon-filter since both API calls return
  everything in one shot regardless.
- Breaks if: the jartc endpoint path or `cmd=filterResults` payload shape
  changes, the `ausstellung`/`j-cc-id`/`datum_von`/`datum_bis`/`permanent`
  field names change, or the Preise page's "Erwachsene € N,-" wording changes.
- Re-derive: open devtools Network tab on /ausstellungen, click "Vorschau",
  copy the resulting POST request.
