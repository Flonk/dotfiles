# schoenbrunn

- url: https://www.schoenbrunn.at/veranstaltungen/alle-veranstaltungen
- method: html (server-rendered, schema.org Event microdata + a matching detail page per event)
- Listing page gives title, category tag, and detail URL. The detail URL is the listing
  href with `/event/` inserted before the slug (e.g. `.../alle-veranstaltungen/<slug>` ->
  `.../alle-veranstaltungen/event/<slug>`) — the plain slug URL just re-renders the
  listing page, not the event.
- Dates: parsed from the visible `<span class="date">DD.MM.YYYY[ - DD.MM.YYYY]</span>`
  fact, not the `itemprop="startDate"/"endDate"` meta tags — at least one observed
  listing had a bogus `endDate` (year before `startDate`) while the visible text was
  correct and had no end at all (single-day event).
- Price only set to 0 when a `icon-price` fact literally says "Eintritt frei"; otherwise
  null (most events have no price fact at all — ticketing happens elsewhere).
- Venue/district: always Schloss Schönbrunn grounds, hardcoded district 1130 (Hietzing).
- Only 4 events published at build time (site runs few self-organised events; Schlosskonzerte
  is a separate ticket vendor, imperialtickets.com, not scraped here). Furthest published
  end date was ~5 months out (Weihnachtsmarkt, through Jan 6). No pagination/load-more
  observed on the listing page — re-check if event count grows a lot, may need pagination.
