- url: https://www.wienmuseum.at/ausstellungen
- method: html (server-rendered, no JSON-LD/API found)
- Listing has 3 sliders by section id: 26817 "Aktuell" (current, incl. permanent
  collection with no dates), 26819 "Vorschau" (announced future), 26820 "Rückblick"
  (past — skipped). Items parsed with regex on li blocks (`newsSliderElem` /
  `twoOneBlock` classes); different markup per slider.
- Date range like "30. April–27. September 2026" parsed with a manual regex + ea.MON;
  missing start-year falls back to the end-year.
- Only 2 venues ever appear (Wien Museum @ 1040, musa @ 1010); district/address are a
  hardcoded lookup by venue name text, not geocoded.
- Price comes from a per-record detail-page fetch of the "Eintrittspreise" collapsible
  section, fed through ea.price().
- Site only lists ~9 exhibitions total (current + preview combined); nothing to
  paginate, horizon_days doesn't really apply.
- Re-derive: view-source the listing page, find `<section id='26817'` /
  `id='26819'`, and adjust the two `.split("<li class='...")` block parsers if the
  CMS markup class names change.
