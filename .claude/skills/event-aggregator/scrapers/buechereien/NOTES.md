# buechereien

- url: https://buechereien.wien.gv.at/veranstaltungen — a DNN portal page with zero data in
  its own HTML. It embeds a DataTables widget (`Portals/0/js/vastat/vatable.js`) whose `ajax.url`
  is the real source: `https://buechereien.wien.gv.at/Portals/0/Files/stb_va/stb_va.json`
  (a static JSON blob, no auth, ~255 occurrences across ~22 branches).
- Method: api (direct GET of that JSON). Re-derive by loading the veranstaltungen page,
  viewing vatable.js, and reading its `ajax.url`.
- No per-event detail page exists. `url` = the record's own pretix ticket link if `url` field
  carries one (type "pretix"), else the branch's own page (built from `zw_web`), else the
  listing page.
- district/address: fetched from each branch's own page (regex on "Adresse: Street, PLZ Wien"),
  22 pages total, cached per run, best-effort — null on fetch failure rather than guessed.
- Host has NO `www.` prefix; `www.buechereien.wien.gv.at` does not resolve (confirmed).
- Publishes ~6 months ahead (max observed start ~2027-02-08 from an early-Aug run); the JSON
  has no pagination, it's just the full current list, filtered here to today..horizon.
- Breaks if: the vatable.js script or its embedded json path moves, or branch pages drop the
  "Adresse:" line format.
