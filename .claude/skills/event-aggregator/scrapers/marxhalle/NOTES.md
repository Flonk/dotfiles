# marxhalle

- URL: https://marxhalle.at/events/ (WordPress + Elementor + JetEngine, custom "events" CPT).
- Method: api. The `/events/` archive and `wp-json/wp/v2/events` REST endpoint
  both looked promising but are dead ends: the archive's visible date is the
  post's *publish* date, not the event date, and REST exposes no event-date
  meta field at all (no taxonomies registered either, so no category).
- Real data source: every event detail page embeds a JetEngine listing widget
  ("WEITERE EVENTS", `listing_id=197`, `custom_query_id=3`) that is the site's
  actual future-events feed, sorted ascending by real event date. It paginates
  via `POST https://marxhalle.at/wp-admin/admin-ajax.php` with
  `action=jet_engine_ajax&handler=listing_load_more`, plus the `query`/
  `widget_settings`/`page_settings[page]` params (hardcoded in scrape.py,
  scraped from a detail page's `data-nav` attribute). jQuery `$.param()`
  bracket-notation encoding is required, not JSON — passing JSON strings
  causes a PHP fatal (500).
- Loop pages until one returns zero `jet-listing-dynamic-post-` items
  (currently ~10 pages / 93 events, out to ~2027-01-30 — comfortably past the
  180d horizon, so no special cutoff logic needed beyond horizon filtering).
- No price or category info exists anywhere on the site; both always null.
  Venue/address/district are hardcoded (single fixed venue: Karl-Farkas-Gasse
  19, 1030 Wien).
- Breaks if: JetEngine listing 197 / query 3 is replaced, or the ajax
  handler/param names change — re-derive from a fresh event detail page's
  `data-nav="..."` JSON blob and `wp-content/plugins/jet-engine/assets/js/frontend.js`.
