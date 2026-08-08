# neueoperwien

- url: https://neueoperwien.at/programm/ (root https://www.neueoperwien.at/ has no
  event data itself, only a link to /programm/)
- method: html. No JSON-LD Event objects, no API. The page is server-rendered
  WordPress/Avada; each production is an `<li class="... post-card ...">` with an
  `<h2><a href>title</a></h2>`, a subtitle `<p>`, then one `<p>dd.mm.yy – Venue</p>`
  per occurrence (Premiere marked inline), and a trailing `<p>Beginn HH:MM TICKETS</p>`.
- One quirk found: a stray duplicated year token ("06.10.26 2026 – Theater am Werk")
  is stripped from the venue text. There's also a likely site typo (an out-of-order
  "06.10.26 – Reaktor" date among Tree of Codes' November dates) — left verbatim,
  not "fixed".
- No per-event price, category, or id on this page; left null rather than guessing.
  Detail pages (e.g. /geschichte/) were not scraped for price to avoid rabbit-holing.
- Horizon: site currently only lists ~4 productions through late November 2026 (its
  whole "Programm 2026" season) — that's the actual publishing horizon, re-check by
  re-fetching /programm/ each run; no pagination exists.
- Re-derive: curl -L /programm/, look for `class="fusion-... post-card ..."` list
  items under `<body`.
