# technischesmuseum

- url: https://www.technischesmuseum.at/ausstellungen
- method: jsonld (detail pages, not the listing page)
- Listing page (`/ausstellungen`) just lists teaser cards with `href="/ausstellung/<slug>"`,
  no dates. Fetch each `/ausstellung/<slug>` page and pull the `ExhibitionEvent` JSON-LD
  block (start/end/description/location).
- Some detail pages have JSON-LD with a literal unescaped newline inside a string
  (invalid strict JSON) -> parse with `json.loads(..., strict=False)`.
- Descriptions are double HTML-escaped (`&amp;lt;sup&amp;gt;`) -> run through `ea.text()` twice.
- All 9 current exhibitions are long-running (some "dauerhaft" i.e. permanent, one ends
  2027, one 2026-08). This site basically only ever lists ~9 exhibitions total; horizon
  pagination is irrelevant, every record is fetched every run.
- The site's own JSON-LD `endDate` for permanent exhibits is a fabricated far-future
  sentinel (e.g. `3000-03-12`, `2040-09-01`) — do not pass it through. Detect permanent
  via the listing page's `<div class="kategorie">dauerhaft</div>` badge or
  `"Dauerausstellung"` in the JSON-LD description; for those, emit `end: null` and
  `extra.permanent: true`.
- No general-admission ticket price found on the exhibition pages -> price_min/price_text
  left null rather than guessed.
