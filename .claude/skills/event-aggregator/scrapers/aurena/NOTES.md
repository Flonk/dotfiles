# aurena

- url: https://www.aurena.at/auktionen — Angular SSR page, single fetch,
  no pagination. All 189 currently-active auctions are present in one blob.
- method: html. The rendered `<auctionentry>` cards carry no id/link, but a
  `<script id=bidware-state type=application/json>` tag holds the full
  Angular TransferState cache, including one key (`package:/180210963@...`,
  duplicated under two hashes) with the complete per-auction record:
  title, category, location, timeInfo (start/end epoch ms), lot count.
- the JSON in that script tag is NOT valid JSON as-is: it uses custom
  entities `&q;`→`"`, `&a;`→`&`, `&l;`→`<`, `&g;`→`>` instead of real
  escaping. Replace those first, then `json.loads`.
- detail URL pattern confirmed live: `https://www.aurena.at/auktion/<id>`
  (SSR-renders correct title for that id).
- record = one auction (many lots each), start = bidding opens, end =
  bidding closes. Site only ever shows ~2 weeks of horizon (all current
  auctions end within ~2 weeks of fetch time), so EA_HORIZON_DAYS is moot
  here — nothing to paginate toward.
- covers all Austria (+ some CH/DE consignors), not Vienna-only: district
  is populated only for the ~2% actually in Vienna; ~42% are pure
  "Versandauktion" (shipping only, no physical venue) with city=null.
- price_min always null: this listing has no per-auction price, only lot
  counts; actual bids live one level deeper (not fetched).
- breaks if: the `bidware-state` script id disappears, the custom-entity
  encoding changes, or the `package:/180210963@` key prefix changes.
