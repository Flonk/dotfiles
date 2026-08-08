# filmarchiv

- url: https://www.filmarchiv.at/ — Phoenix LiveView app, but the initial
  GET is fully server-rendered, incl. `/?day=YYYY-MM-DD` (a `phx-link:patch`
  link that works fine as a plain query param over curl).
- method: html. Walk `/?day=YYYY-MM-DD` from today for up to 60 days
  (stopping after 10 consecutive empty days) collecting `/de/kino/film/sc_*`
  ids from the day's screening widget. Each `sc_` id is a "programme item"
  detail page listing every future showtime for that item (date, time,
  venue/room, a `ticket-checkout/<uuid>` link used as `source_id`), plus
  description and a Regie/Land/Jahr/... metadata block kept in `extra`.
- `category` = the "Im Rahmen von" series link text (e.g. `Kinostart: Kota`,
  `Kino wie noch nie: Timothée Chalamet`) — verbatim, not normalised.
- venue → district: `Metro Kinokulturhaus` = 1010 (Johannesgasse 4);
  `Naturarena Open Air` / `Atrium Open Air` (both "Kino wie noch nie" /
  Augarten open-air) = 1020. Hardcoded map, extend if a new venue appears.
- price never appears server-side (ticket widget is a JS iframe), so
  price_min/price_text are always null.
- horizon: site only publishes ~3 weeks ahead in practice (build on
  2026-08-08 reached through 2026-08-30); horizon_days set to 30.
- breaks if: the `p-4 border-black` showtime row markup, the
  `font-bold text-s35` date/time span, or the `/de/kino/film/sc_` URL
  pattern changes. Re-derive by viewing `/?day=<near date>` and a
  `/de/kino/film/sc_...` detail page.
- runtime was already free: the metadata block parses every `Regie:
  .../Land: .../Länge: 100 min` field verbatim into `extra`, and `Länge`
  is one of the pipeline's recognised runtime keys — 100% fill, no
  change needed.
- image: added the detail page's `<meta property="og:image">`
  (img.filmarchiv.at CDN) — same page already fetched, no extra
  requests, ~99% fill (one item had no still on site).
