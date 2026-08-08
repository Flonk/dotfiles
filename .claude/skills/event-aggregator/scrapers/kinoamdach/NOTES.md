# kinoamdach

- url: https://www.kinoamdach.at/ (301 -> https://www.gogogo.at/kinoamdach, Wix)
- method: html — regex over `ea.text()` of the homepage banner. No ld+json, no XHR/API
  found, and individual film titles/dates are not present in any server-rendered HTML
  (checked filmprogramm/schedule/cinema/event sub-pages — they all render the identical
  client-side-routed shell; the Wix Events app data is fetched by JS at runtime, not SSR'd).
- So this emits ONE record for the whole season (like a long-running exhibition), from
  the announced "01. JUNI – 12. SEPTEMBER 2026" banner, season number ("#23"), theme
  motto, price block (€12 / €11 reduced -> price_min=11), and address.
- Publishes only the season block; no per-screening dates ever appear as text on-site.
- Re-derive: refetch homepage, regex for the date-range banner line and the
  "Eintrittspreis...Kulturpass]" price block; if Wix redesigns the banner wording these
  two regexes are what breaks first.
