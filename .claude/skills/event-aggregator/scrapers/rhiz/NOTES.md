# rhiz

- url: https://rhiz.wien/
- method: api - `GET /wp-json/copilot-promotion/v1/promotions` (site's "Copilot Events"
  WordPress plugin). Returns all upcoming events unpaginated in one JSON response; each
  record has a `rawEvent` field that's itself a JSON string with the full event detail
  (doors/start/end, venues, description html, presaleLink, status).
- Publishes ~4 months out (Sep-Dec 2026 at build time). No pagination controls needed,
  everything comes back in one call, `EA_HORIZON_DAYS` just trims the tail.
- Detail URL doesn't exist server-side; reconstructed as
  `https://rhiz.wien/?copilot-slug=<slug>` to match the plugin's client-side routing
  (`Bn`/`encodeURIComponent(t.slug)` in view.js).
- price_min/price_text left null: no structured price field on the API; some
  descriptions mention door price/donation in free text but that's not safe to parse.
- Re-derive: re-fetch https://rhiz.wien/ and grep for `copilot-promotion` to confirm the
  plugin is still in use; if the endpoint 404s, check
  wp-content/plugins/copilot-promotion/build/view.js for the current REST namespace.
