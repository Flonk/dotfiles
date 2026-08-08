# khm

url: https://www.khm.at/besuchen/ausstellungen/ (redirects to /besuchen/ausstellungen -> /ausstellungen)
method: html — server page has no JSON-LD; cards are loaded via HTMX fragments
(`hx-get="/ausstellungen/x.htm?ce=...&cHash=..."`) that return plain HTML card
markup. Script fetches the main page, discovers each `data-title` section's
htmx fragment URL, fetches each fragment, and also fetches
`/ausstellungen/vorschau` + its one fragment for future exhibitions.

Sections found: "Dauerausstellungen" (permanent, main building), "Sonderausstellungen"
(temporary, dates on card or in detail page's `has-icon` infobox), "Dauerausstellungen
Neue Hofburg" (permanent, Heldenplatz), plus a duplicate "Sommerausstellung" teaser
(overwritten by dedup-by-slug) and "Vorschau" (future specials, full date ranges
already on the card).

Special exhibitions with only a "bis DATE" on the card get their real start from
the detail page's `<p class="has-icon">date_range...` infobox; if that infobox is
absent (e.g. small "Vitrine Extra" showcases), start falls back to today. Exhibitions
with no end published ("seit DATE" or fully undated permanent collections) get
`end: null`, `extra.permanent: true`, and start defaults to today if unknown.

Only covers the main KHM building + Neue Hofburg. Weltmuseum, Theatermuseum,
Schatzkammer (external kaiserliche-schatzkammer.at) and Wagenburg are separate
sites, not reachable from here — not covered.

Breaks if: htmx endpoint path/params change, the `has-icon` infobox markup on
detail pages changes, or `data-title` section headings are renamed.
