# volkskundemuseum

- url: https://www.volkskundemuseum.at/ (jart CMS, same platform as MAK)
- method: html, three sources combined in scrape.py.
  1. `/termine`: `<div class="teaser-element-holder ... dbid_N">` blocks, one
     per dated occurrence (tours, Mostothek, concerts). Grouped by `<h2>`
     month header. Only lists ~7 weeks ahead right now (Aug-Sep 2026); the
     "Alle Veranstaltungen anzeigen" link just reloads the same unfiltered
     URL, no deeper pagination exists on-site. Category is not on the
     teaser itself, so the 9 `/termine?article_category_id=<id>` filter
     pages (ids hardcoded from the filter-item links) are re-fetched to
     build a dbid -> category map.
  2. `/programm/aktuell`: same teaser markup, 2 long-running installations
     (MUSMIG-Raum, Hof der Kulturen) with explicit far-end dates (2027) ->
     one record each. `subtitle-info` on this page is a tag ("Pilotprojekt"),
     not a location, so venue/address/district are hardcoded to the Otto
     Wagner Areal since the main Laudongasse building is closed.
  3. `/ausstellung/meet_otto`: a distinct detail-page template ("Seit
     15.10.2025", no end) -> one permanent record, `extra.permanent: true`,
     `price_min: 0` since the page says "Eintritt frei".
- No price info anywhere except the meet_otto opening-hours note.
- Re-derive: refetch `/termine`, confirm `teaser-element-holder` still
  present and the date/title/subtitle-info markup unchanged.
