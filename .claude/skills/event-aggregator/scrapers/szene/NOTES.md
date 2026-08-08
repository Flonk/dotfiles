# szene (Szene Wien)

- url: https://szene.wien/ (WordPress + Elementor + Events Manager + WP Grid Builder)
- method: api. The homepage's "upcoming events" masonry grid (grid id 1) is populated via
  WP Grid Builder's admin-ajax action: `POST https://szene.wien/?wpgb-ajax=refresh&_mehr_laden=<offset>`
  with form field `wpgb={"is_main_query":false,"main_query":[],"permalink":"https://szene.wien/",
  "facets":[1,2],"lang":"","id":1}`. Response JSON has `posts` (HTML string of `<article>` cards),
  `total`. Batches are fixed at 12 regardless of the offset passed; page with `_mehr_laden=0,12,24,...`
  until `offset > total`. No nonce required.
- Each card gives title, free-entry flag, date (no time), and detail URL + wp post id
  (`wpgb-post-<id>`, used as source_id). Detail page (`/events/<slug>/`) is fetched per event for
  exact `Beginn` time, price/ticket info, address, description — no JSON-LD on detail pages.
- Single fixed venue for every event: Hauffgasse 26, 1110 Wien.
- Breaks if: WP Grid Builder plugin changes (grid id 1, facet ids [1,2], batch size 12), or the
  admin-ajax endpoint starts requiring a nonce, or the site restructures event detail markup
  (`class = "time"/"location"/"einlass"/"beginn"/"tickets"`, note the literal ` = ` spacing).
- Re-derive: view-source the homepage, find `wpgb_settings` and the `?wpgb-ajax=action` string;
  the `/events/` archive itself is NOT usable (its main query defaults to `scope:"past"` and shows
  a different, non-upcoming set — ignore it).
- Site publishes ~14 months ahead (91 events found through Oct 2027 at build time); the default
  90-day horizon trims that to 57 emitted records.
