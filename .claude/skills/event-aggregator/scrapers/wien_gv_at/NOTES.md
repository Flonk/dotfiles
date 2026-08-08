# wien_gv_at

- Declared url `veranstaltungen.json` is a GeoJSON point layer with title/id/description/url
  only — no dates. Real data is the ES search proxy the frontend calls:
  `POST https://search.wien.gv.at/site_veranstaltungen/_search/template`
  body `{"id":"search_template_specific","params":{"query_string":"","filters":[],"from":0,"size":1000}}`.
  Requires `Origin`/`Referer: https://www.wien.gv.at...` headers and header
  `Authorization: ApiKey ` (empty key) — without Origin/Referer it 401s.
- One call returns all ~574 currently-listed events. Each hit's `_source.daoh_edit.logic.sets`
  holds either `type:"single"` (explicit dates array, one entry per showtime — exploded to one
  record each) or a recurring/opening-hours set with `ranges[].from/to` (collapsed to one
  record per range, like an exhibition).
- Site publishes out to ~5-6 months ahead (observed max start ~late Jan from an early-Aug
  run, with a 180-day horizon); no real pagination, so `size:1000` always captures
  everything currently listed.
- Breaks if: the ES template id/field names change, or the Origin/Referer gate tightens.
  Re-derive by loading https://www.wien.gv.at/veranstaltungen in a browser devtools network
  tab and copying the XHR to search.wien.gv.at.
- category = comma-joined `defined_terms[].title` verbatim (site has no single category field).
- end: already handled, no change needed (2026-08-08 audit). `dates[].to` /
  `ranges[].to` in daoh_edit are genuine when they differ from `from`
  (~77% of single-occurrence dates); the remaining ~23% have `to == from`
  in the source itself - the site publishes no duration for those (checked
  free-text `content` for a couple, confirmed no end time anywhere), so
  they correctly stay null rather than being guessed.
