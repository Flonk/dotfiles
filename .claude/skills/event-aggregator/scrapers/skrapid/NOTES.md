# skrapid

url: https://www.skrapid.at/teams/spielplan (Nuxt SPA, no data server-rendered)
method: api

Fixture data comes from the WP REST API at `cms.skrapid.at/wp-json/wp/v2/match`
(discovered by grepping the shipped Nuxt JS bundles for the store's `$fetch`
call). Paginate with `?per_page=100&page=N` until a short page. Each match has
a `meta.sk_match_*` block: date, time, status (Played/Fixture/Cancelled/empty),
competition id, venue, matchday. Competition names come from
`wp/v2/competition`. A handful of rows have empty title/date (placeholder
posts) — skipped.

Covers every SK Rapid team (men's Bundesliga, women's, youth, 2. Liga), not
just the pro squad. No public per-match detail page resolves (the `link`
field from the API redirects off-site), so `url` is the general schedule
page for all records.

Breaks if: the `sk/wp-json/wp/v2/match` route disappears or meta key names
change (rename `sk_match_date` etc). Re-derive by grepping `_nuxt/*.js` for
`sk_match_date` or `fetchMatches`.

Site publishes fixtures roughly through the following season (~8 months out
in this snapshot, to 2027-04); horizon_days=180 is a reasonable cutoff.
