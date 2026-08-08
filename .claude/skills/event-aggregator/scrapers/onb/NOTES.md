# onb (Österreichische Nationalbibliothek museums)

- url: https://www.onb.ac.at/museen — landing page for 5 sub-museums: Prunksaal,
  Literaturmuseum, Papyrusmuseum, Globenmuseum, Esperantomuseum. Server-rendered
  TYPO3 HTML, no JSON-LD/API. method = html.
- Exhibitions: for each museum, fetch `/museen/{m}` and follow `programm/*` and
  `besuch/*dauerausstellung` links (skip `vergangene-*` archives and
  `*wanderausstellung*` — those are touring shows hosted abroad, not in Vienna).
  Detail pages have the date range as plain text like "20. März 2026 – 1.
  November 2026" or "13. Juli bis 11. Oktober 2026" right after an anchor-button
  section; `Dauerausstellung` pages have no date at all → emitted as
  `extra.permanent: true`, `end: null`, `start` = today (never guessed forward).
- Events: each museum's `/kalender` lists both one-off dated events and
  recurring bookable activities (guided tours, baby tours). Only the former show
  a date, in a `<div class="detail-meta"><strong>DD. Month YYYY</strong>...`
  block; the latter only link out to an external ticket shop with no date on
  ONB's own page — skipped rather than guessed. Joint events (Lange Nacht der
  Museen, Tag des Denkmals) are cross-listed identically under every
  participating museum's kalender; deduped by (title, start).
- Horizon: kalender pages only show ~2-4 months ahead per museum; exhibitions
  are announced further out (some "Vorschau" shows dated 6+ months ahead).
  EA_HORIZON_DAYS is not enforced as a hard cutoff since there's nothing to
  paginate — the site itself doesn't publish further out.
- Fragile bits: the `allerhoechste-familie.../i` URL has a stray `/i` path
  segment baked into the site's own link — kept verbatim. Canary
  `detail-meta` is the div class the date-parsing depends on.
