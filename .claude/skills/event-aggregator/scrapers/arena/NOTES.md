# arena

- url: https://arena.wien/Home/Programm (DNN/DotNetNuke site)
- method: api. The programme page's JS calls
  `GET /DesktopModules/WebAPI/API/Event/Search?searchTerm=&day=1&month=-1&year=-1&page=0&pageSize=10000&eventCategory=-1&abonnement=-1&cultureCode=de-AT&locationId=0`
  which returns `{"concerts":[...], "maxPage":N}`. A single call with a large
  pageSize returns every upcoming concert (~138 as of 2026-08-08, spanning to
  Oct 2027), so no real pagination is needed; we just filter to `ea.horizon()`.
- Fields used: DateBegin, DateEnd (always null so far), Title, Subtitle,
  Location, DetailUrl (contains `concert-id/<id>` used as source_id).
- CategoryName/SoundWorldName are always empty strings in this API — category
  is left null, not fabricated.
- Price is NOT in the API; it's only in each detail page's og:description
  meta tag. Fetching detail pages per event was attempted but the site
  intermittently hard-times-out TCP connects after a handful of rapid
  requests (even with 2s retries + 0.3s delay), blowing past the 5min check
  budget. Dropped it — price_min/price_text are always null here.
- Re-derive: if the endpoint path changes, view-source the Programm page and
  find the `$.ajax({url: ...})` call in the inline script.
- Breaks if: the WebAPI path or query param names change, or DNN
  `event-template` script id disappears (confirms this is still the module
  in use).
