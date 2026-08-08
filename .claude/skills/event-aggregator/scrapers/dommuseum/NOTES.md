# dommuseum

- url: https://www.dommuseum.at/ ; calendar: https://dommuseum.at/category/kalender
- method: html. `<div class="category_list_item ..." aid="N">` blocks on the kalender
  page give date/time, title, category+venue, teaser, detail url per occurrence.
- The current temporary exhibition ("Aktuelle Ausstellung") is found via the homepage
  slider (`homeSliderText` block whose label starts with "Ausstellung"), then its own
  page's `start_subtitle` div gives the "3. Oktober 2025 – 30. August 2026" range ->
  emitted as one long-running record. price_min for it comes from the regular ticket
  price on /tickets ("Regulär € N"); workshop/tour calendar entries have no listed
  price anywhere so price_min is left null.
- Site horizon is short: only publishes ~4 calendar entries, roughly 7 weeks ahead
  (site itself has no pagination for this list — it's just thin).
- Breaks if: `category_list_item`/`list_item_date`/`list_item_title`/
  `list_item_category_place`/`list_item_teaser` class names change, or the homepage
  slider markup (`homeSliderText`/`sliderMoreButton`/`h2`) changes, or the exhibition
  detail page stops using `start_subtitle` for its date range.
- Re-derive: curl the kalender URL and homepage with a browser UA, grep for the class
  names above.
