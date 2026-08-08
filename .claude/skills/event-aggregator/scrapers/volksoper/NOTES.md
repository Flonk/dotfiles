# Volksoper

- url: https://www.volksoper.at/spielplan/
- method: html, server-rendered. Month pages: `/spielplan/<german-month>-<year>.de.html`
  (e.g. `september-2026`, umlaut months like `jänner`/`märz` need URL-encoding).
- Each `<article class="event event-list-item">` is one occurrence; skip articles with
  no `itemprop="url"` link (these are "keine Vorstellung" placeholder days). start/end
  come from `itemprop="startDate"/"endDate"` content attrs.
- Site publishes roughly to mid-2027 at time of writing (month dropdown goes ~10 months
  out); scraper only walks to `ea.horizon()`.
- Quirk: months with zero shows (Volksoper is dark in August) silently render the next
  month's listing instead of an empty page — same HTML, different `<title>`. Handled via
  dedup on (source_id, start), harmless extra fetch.
- No real category taxonomy on the listing (just CSS state classes like `event-premiere`,
  `weekend`) — left `category` null. Price is a tier label ("Preise A".."Preise Z"), not
  a number — `price_min` always null, `price_text` holds the label.
- Re-derive: view-source the URL, look for `<select id="filter-month">` for valid month
  slugs and `<article itemscope itemtype="http://schema.org/Event">` for the record shape.
