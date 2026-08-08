# Planetarium Wien

- url: https://www.planetarium-wien.at/ (301s to https://www.vhs.at/de/e/planetarium — VHS Wien course platform)
- method: html, paginated server-rendered search listing at
  `www.vhs.at/de/e/planetarium/veranstaltungen?...&f.sem_grouping=sem_grouping:kurs&q=*&f.showcourses=buchbare&group.offset=N`,
  10 results/page. Each dated show is its own `<article class="courseOverviewItem ...">`
  with id, title, subtitle, price, one date/time (`1 Termin, DD.MM.YYYY / Sa, HH:MM - HH:MM Uhr`),
  and venue text. Covers all three sites: Planetarium (1020), Urania Sternwarte (1010),
  Kuffner Sternwarte (1160) — venue mapped to district/address via a hardcoded dict.
- category: only available as a CSS modifier class on the `<article>` tag
  (`courseOverviewItem--naturwissenschaften-und-technik` / `--science`), mapped back to the
  site's own filter-sidebar labels ("Naturwissenschaften und Technik" / "Science"). No
  finer sub-category (e.g. "Astronomie") without fetching every detail page.
- price: shown inline on the listing card; ~8% of shows (mostly "Himmelsbeobachtung" /
  rooftop observation nights) have no listed price on the card even though the detail page
  states a nominal price — left `price_min: null` rather than guessing.
- publishes ~10 months out (last seen 2027-06); scraper stops once `ea.horizon()` cutoff
  (EA_HORIZON_DAYS, default 180) is exceeded, sorted ascending by `sem_event_start`.
- breaks if: the `courseOverviewItem` markup/class names change, or the `group.offset`
  paging param is renamed. Re-derive by loading the veranstaltungen URL above in a browser
  and diffing the article HTML.
