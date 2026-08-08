# Vienna event aggregator — findings

Exploration only, nothing built. Two sections: what Flo wants, and what to scrape.
Probe tool: `probes/probe.sh` (status, size, JSON-LD count, `Event` count, Claude robots block).

---

# 1. What I want

## The trigger

Cycled home, saw a festival in the park next door. Saw a Romanian folk dance in another park
on a random Sunday. Would have loved to know about both.

## Two jobs

- **Discovery** (build first) — surface things Flo doesn't know exist. Needs ranking:
  ~70–80 events/day happen in Vienna, he'll read ~5.
- **Tracking** (second) — watchlists for named artists, venues, annual events. Needs lead
  time, not day-of. (K&D sold out before he heard.)

## Three lanes — nothing is ever discarded

| Lane | Meaning |
|---|---|
| **Surface** | matches interest → daily digest |
| **Backlog** | doesn't match → stored, monitored, **promoted if a bargain appears** |
| — | there is no discard lane |

Backlog exists because interest is price-dependent: schlager concerts, La Traviata "for the
nth time", Rapid vs Austria, non-followed artists — all "yes, if cheap enough".

**Consequence: bargain detection is core infrastructure, not a phase-2 feature.** It is the
promotion mechanism for five separate categories. Second consequence: things Flo
deprioritises (opera, routine cinema) still have to be *ingested*, because you can't backlog
what you never fetched.

## The core discriminator: specificity, not category

A marine-mammal congress, a Romanian folk dance, Kurdish jazz, and a cleared hotel auctioning
its furniture are the *same kind of thing*. A generic flea market and the nightly Staatsoper
programme are the other kind.

There is no category whitelist. A weirdly specific instance of a category he'd otherwise
ignore beats a generic instance of one he likes. Flea markets: "really dont care" — but a
hotel clearance auction is "fucking cool". Same category, opposite verdict.

## Categories and priority

| Priority | Category | Rule |
|---|---|---|
| ★★★ | **Congresses/conferences, esp. IT** | Flo is a programmer. "If there is a congress on marine mammals whatever the hell I'd like to know" — rates above flea markets |
| ★★★ | **Participatory sport** | highest enthusiasm in the list. Strasser Workout, runs |
| ★★★ | Music festivals | always important |
| ★★☆ | Concerts — followed artists | filter by Spotify follows → surface |
| ★★☆ | Trade fairs & expos | Erotikmesse, Haustiermesse, Comic Con, Spielefest |
| ★★☆ | Food & drink festivals | Whisky Festival, Genuss-Festival (Stadtpark) |
| ★★☆ | Museum exhibitions | **architecture ×2, modern architecture ×2 again** — but biology, tech, history all in scope |
| ★★☆ | Offbeat opera / literature / readings | canonical repertoire → backlog |
| ★☆☆ | Experimental electronic, non-club dance, world/jazz | "semi-important", discovery lane |
| ★☆☆ | Kirtage, Straßenfeste, demos ("the wien.gv.at stuff") | "sure" |
| ★☆☆ | Cinema — festivals & special programmes only | routine screenings **excluded** |
| ☆☆☆ | Major spectator sport | World Cup yes; regional → backlog |
| — | Generic flea markets | backlog |

## Ranking signals

1. **Free or cheap** — but see arbitrage below
2. **Rare / one-off** — run-length is measurable and collapses ~50/day to ~4/day
3. **Specificity / unusualness**
4. **Proximity** — a weight, not a cutoff. Vienna for now; a big enough event justifies 2–3 h by train

**Price is a value, not a boolean.** Free things rank up *and* expensive things acquired
cheaply rank up: "pay 5€ for a 1000€ conference ticket and even get free food out of it.
It's arbitrage." Unifying concept is **value per euro paid**. Store face value + currency.

## Known-unsolved

- **The music discovery lane.** Flo: *"Specificity is important but I don't believe you can
  find a heuristic for this."* Kurdish jazz was one of his best concerts ever; no genre tag
  predicts that. Don't fake a solution.
- **How to measure "magnitude"** for the train-ride rule. No source field maps to it.
- **Facebook-only events are unreachable.** Walletschek Laien Akkordeon Ensemble is a real
  ensemble with real gigs listed nowhere machine-readable. Permanent coverage ceiling.
- **No retrospect** unless history is captured from day one.
- **Dedupe is mandatory** — Popfest appeared in 5 sources at once.

## Still needed from Flo

- STEM/humanities topic picks (list was ~60 checkboxes; IT confirmed top)
- Home district, for proximity weighting
- Calendar shape, filter aggressiveness, history, lead time — all deliberately deferred

---

# 2. What sites to scrape

**Volume reality:** wien.gv.at alone yields 45–58 occurrences/day; ~70–80/day combined.
Rarity filter (≤3-day runs) cuts that to 0–11/day, median 4.

## Tier A — `Event` JSON-LD, no Claude block. Do these first.

| Source | URL | Covers | Yield |
|---|---|---|---|
| **Eventbrite** | `eventbrite.at/d/austria--vienna/<cat>--events/` | **IT, science, business, music, arts, sport** | 16–40 each |
| | `…/science-and-tech--events/` · `…/business--events/` | conferences ★★★ | 16 · 16 |
| | `…/sports-fitness--events/` (`austria--wien`) | participatory sport ★★★ | 40 |
| | `…/music--events/` · `…/arts--events/` | | 16 · 16 |
| **wien.gv.at** | `wien.gv.at/veranstaltungen.json` → detail pages | city/community, festivals, Grätzl, markets, kids | 611 events / 2450 occurrences |
| **volume.at** | `volume.at/events/` | concerts, festivals, trade fairs | schema.org + **price** |
| **meinbezirk.at** | `meinbezirk.at/event/wien/list/{today,tomorrow,weekend}` | hyperlocal, district-tagged | ~35/day, 48 pages |
| **MAK** | `mak.at/programm` | design/architecture museum | **50** |
| **Technisches Museum** | `technischesmuseum.at/ausstellungen` | tech museum | **22** |
| **Belvedere** | `belvedere.at/ausstellungen` | art museum | 8 |
| **vienna-events.com** | `vienna-events.com/en/events` | general aggregator | 20 |
| **Klimt Villa** | `klimtvilla.at` | | 4 |
| **maw.co.at** | `maw.co.at/de/kongresskalender` | **medical/scientific congresses**, 494 entries, clean `data-town`/`data-month`/`data-year`. No robots.txt | |
| **porgy.at** | `porgy.at/events/upcoming` | jazz/world, 168 events. Parser written | |

wien.gv.at notes: index is undocumented, ~42 s response, no dates — dates live in
schema.org `Event` JSON-LD on detail pages (`subEvent[]` for occurrences, `geos`,
`addresses`, `additionalProperty` tags incl. `Grätzl` 41, `Fest` 68, `Markt` 21,
`Outdoor` 223). The official OGD dataset is **dead** (retired Dec 2025, no replacement).

## Tier B — server-rendered, no JSON-LD. One bespoke parser each.

### Museums — federated under a few operators

**This is the key cost saver: ~40 institutions collapse to ~12 scrapers. Verified
2026-08-08** — group pages do list their sub-venues. Mention counts in the fetched HTML:
`khm.at` → Weltmuseum 11, Theatermuseum 8, Schatzkammer 7, Wagenburg 6.
`wienmuseum.at` → Beethoven 71, Hermesvilla 35, Prater Museum 31, Uhrenmuseum 24, MUSA 22.

| Operator | URL | Institutions covered |
|---|---|---|
| **KHM-Museumsverband** | `khm.at/besuchen/ausstellungen/` | KHM, Weltmuseum (`weltmuseumwien.at`), Theatermuseum (`theatermuseum.at`), Kaiserliche Schatzkammer (`kaiserliche-schatzkammer.at`), Wagenburg, Neue Burg |
| **Wien Museum** | `wienmuseum.at/ausstellungen` | Wien Museum, MUSA, Uhrenmuseum, Römermuseum, Hermesvilla, Prater Museum, Beethoven, Schubert, Haydnhaus, Otto Wagner Pavillon, Virgilkapelle |
| **Schönbrunn Group (SKB)** | `schoenbrunn.at` · `hofmobiliendepot.at` | Schloss Schönbrunn, **Möbelmuseum/Hofmobiliendepot**, Sisi Museum, Kaiserappartements, Silberkammer |
| **ÖNB** | `onb.ac.at/museen` | Prunksaal, Literaturmuseum, Papyrus-, Globen-, Esperantomuseum |
| **Albertina** | `albertina.at/ausstellungen/` · `/albertina-modern/` | both houses |

Standalone (one scraper each):

`azw.at/de/programm/` ★ **architecture — also hosts Architektur.Film.Sommer** ·
`mumok.at/de/ausstellungen` · `leopoldmuseum.org/de/ausstellungen` ·
`nhm-wien.ac.at/ausstellung` (biology; incl. Narrenturm) · `secession.at/ausstellungen/` ·
`jmw.at/ausstellungen` · `kunsthauswien.com` · `dommuseum.at` · `hdgoe.at` ·
`freud-museum.at` · `volkskundemuseum.at` · `hgm.at` · `josephinum.ac.at` ·
`hausdermusik.com` · `mozarthausvienna.at` · `ernstfuchsmuseum.at` (architecture) ·
`bestattungsmuseum.at` · `hofburg-wien.at` · `srs.at` (Spanische Hofreitschule) ·
`zoovienna.at` · `kindermuseum.at` (302) · `schmetterlinghaus.at` · `haus-des-meeres.at` ·
`planetarium-wien.at`

All 25 probed 2026-08-08: reachable, **none block Claude**, none carry `Event` JSON-LD
except Klimt Villa. Dead: `thirdmanmuseum.at`, `kunstforumwien.at` (connection failed),
`kriminalmuseum.at` (1 KB stub).

### Music & venues

`konzerthaus.at/de/programm-und-karten` (430 KB) · `wuk.at/programm/` (436 KB) ·
`wienmodern.at/programm/` · `brut-wien.at/de/programm` · `echoraum.at/programm/` ·
`rhiz.wien` · `fluc.at/programm/` (6 KB, thin) · `wien-ticket.at`

These five — WUK, rhiz, Fluc, echoraum, brut — are the **only permitted route to the
club/experimental lane**, since Resident Advisor blocks Claude.

### Theatre & opera

`burgtheater.at/spielplan` (292 KB) · `volkstheater.at/spielplan/` ·
`volksoper.at/spielplan/` · `josefstadt.org/programm/spielplan.html`

### Cinema — 17 venues from `wien.gv.at/kultur/programmkinos` (official directory)

All probed 2026-08-08: **every one HTTP 200, none blocks Claude.**

| Cinema | URL | Size |
|---|---|---|
| Bellaria Kino | `bellariakino.at/de` | 420 KB |
| Filmcasino | `filmcasino.at` — **also hosts Japannual** | 238 KB |
| Stadtkino | `stadtkinowien.at` | 233 KB |
| Nonstop Kino | `nonstopkino.at` | 161 KB |
| Votivkino | `votivkino.at` | 144 KB |
| Breitenseer Lichtspiele | `breitenseer-lichtspiele.at` | 139 KB |
| Filmarchiv Austria | `filmarchiv.at` — also *Kino wie noch nie* | 115 KB |
| Top Kino | `topkino.at` | 89 KB |
| Österr. Filmmuseum | `filmmuseum.at` | 85 KB |
| Schikaneder | `schikaneder.at/jart/prj3/schikaneder/main.jart` | 78 KB |
| Gartenbaukino | `gartenbaukino.at` | 68 KB |
| Admiral Kino | `admiralkino.at` | 49 KB |
| Cinecenter | `cinecenter.at` | 34 KB |
| Burg Kino | `burgkino.at` | 26 KB |
| Haydn Kino | `haydnkino.at/Cinema/Overview` | 23 KB |
| Actors Studio | `cineplexx.at/cinemas/Actors-Studio` | 6 KB |
| Urania Kino | `cineplexx.at/cinemas/Urania-Kino` | 6 KB |

Plus festival hosts from `wien.gv.at/kultur/sommerkinos`: `japannual.at` ·
`kinoamdach.at` · `filmfestival-rathausplatz.at` · `volxkino.at` ·
`azw.at/de/termin/architektur-film-sommer-2026/` · `viennashorts.com` ·
`slashfilmfestival.com`

**Scrape for festivals/retrospectives only, not routine screenings.**

Festival index: `wien.gv.at/kultur/sommerkinos` (official, links to each host) and
`visitingvienna.com/entertainment/events/film-festivals/` (~28 entries — but **Japannual is
missing from it**, so never treat as authoritative).

~30 annual festivals identified. Notable: **Architektur.Film.Sommer** (Az W, Jul–Aug Weds),
Viennale (Oct), /slash (Sep–Oct), Vienna Shorts (May), this human world (Nov–Dec),
Ethnocineca, UNDER_the_RADAR, Wiener Arbeitsfilmfestival, Blue Danube, Stumm & Laut,
**Science Fiction im Park** (free), Kino am Dach (Jun–Sep), Kino wie noch nie, Japannual.

### Fairs, sport, other

`marxhalle.at/events/` · `messecongress.at` · `ottakringerbrauerei.at/de/events/` ·
`vienna-capitals.at/spielplan` · `fk-austria.at/teams/profis/spielplan` ·
`vienna-marathon.com` · `alte-schmiede.at`

## Tier C — blocked or unusable

### robots.txt disallows Claude

| Site | Directive | Cost |
|---|---|---|
| **ra.co** (Resident Advisor) | `Claude-Web`, `ClaudeBot`, `anthropic-ai` → `Disallow: /` | the obvious club/electronic source |
| **wiener-staatsoper.at** | `ClaudeBot` → `Disallow: /` | breaks the opera backlog plan |
| **theater-wien.at** | `ClaudeBot` → `Disallow: /` | |
| **viennale.at** | `anthropic-ai`, `Claude-Web` → `Disallow: /` | biggest film festival |
| **kunsthallewien.at** | `ClaudeBot` in blocked group | |
| **falter.at** | blocks ~50 AI agents; `*` is allow-all | best cultural coverage in Vienna |
| oefb.at | `anthropic-ai` — **subagent claim, not verified** | |

### Technical failures

`ticketswap.at` 403 — **the bargain monitor is blocked at the front door**, and it drives
the whole backlog · `10times.com` 403 · `wikicfp.com` no connection ·
`genuss-festival.at` no connection · `literaturhaus.at` no connection ·
`musikverein.at/spielplan/` 695-byte JS shell · `songkick.com` 406

### Verified negatives — do not re-investigate

- **No Vienna museum-exhibition aggregator exists.** `ganz-wien.at/kunst-kultur/ausstellungen.html`
  was claimed to cover "12+ museums, 30+ exhibitions with dates" — checked directly: 67 KB of
  site chrome, **zero** hits for Albertina/mumok/Leopold/Belvedere/MAK/KHM/Weltmuseum/
  Technisches, no dates. The federated-operator table above is the real answer.
- **`clocate.com` is not a Vienna conference listing.** Claimed "59 Vienna conferences";
  `/conferences-in+austria/` has no listing links, `/conferences-in-vienna/` redirects to a
  single event page.
- **Non-medical, non-IT academic conferences still have no dedicated source.** MAW is
  medical-only (`Zahnmedizin` 5 hits, `Games` 0, `WeAreDevelopers` 0). Eventbrite covers
  tech/science/business. A marine-mammal congress remains unhomed.

## Gap audit — every list item vs. its source

Probed 2026-08-08. This is the answer to "have you found a source for each item".

### Sourced ✅

| Item | Source |
|---|---|
| Concerts — followed artists / backlog | volume.at (+ Spotify `user-follow-read`, scope already granted) |
| World & offbeat jazz | porgy.at |
| Music festivals | wien.gv.at, volume.at |
| Kirtage, Straßenfeste | wien.gv.at, meinbezirk |
| Museums (all ~40) | 5 operator groups + ~24 standalones |
| Architecture ×2 | azw.at, MAK, Ernst Fuchs |
| IT conferences & meetups | eventbrite (science-and-tech, business) |
| Trade fairs | volume.at, marxhalle.at, messecongress.at, `wko.at/veranstaltungen` |
| Flea markets (backlog) | wien.gv.at `Markt` tag |
| Participatory sport | eventbrite sports-fitness (40), vienna-marathon.com |
| Regional spectator sport | vienna-capitals.at, fk-austria.at |
| Cinema festivals | `wien.gv.at/kultur/sommerkinos`, 16-venue directory, **japannual.at** (8–15 Oct, at Filmcasino) |
| Literature & readings | **literaturhaus-wien.at**, alte-schmiede.at |
| Auctions / clearances | **`aurena.at/auktionen`** — ~188 active auctions, ~63 k items incl. estate sales, business liquidation, furniture. Server-rendered core, robots allows all. Dorotheum blocked |
| **Academic conferences, non-med non-IT** | **10 institutional calendars** — no aggregator exists, but together these cover the field. All probed 2026-08-08: **all HTTP 200, none block Claude, none carry `Event` JSON-LD** |

### Academic & research calendars — the marine-mammal-congress answer

There is **no national or city research-events aggregator**. Coverage comes from scraping
institutions directly. Each needs its own parser.

| Institution | URL | Fields | Note |
|---|---|---|---|
| **TU Wien** | `tuwien.at/en/tu-wien/news/events` | engineering, CS, physics, maths | **largest** — 15/page × 41 pages |
| **Universität Wien** | `kalender.univie.ac.at` | all fields incl. philosophy, linguistics | TYPO3, 25 dated entries, detail at `/einzelansicht?…` |
| **ESI** (Erwin Schrödinger Inst.) | `esi.ac.at/events/` | maths, mathematical physics | ~23 |
| **ISTA** | `ista.ac.at/en/news-events/events/` | physics, life sciences, CS | |
| **IMP / Vienna BioCenter** | `imp.ac.at/calendar` | **molecular biology, life sciences** | ~15 |
| **NHM Wien** | `nhm.at/veranstaltungskalender` | **natural history, zoology, marine** | robots has a 50+ bot blocklist, **Claude not on it** |
| **BOKU** | `boku.ac.at/event/list` | ecology, agriculture, environment | |
| **WU Wien** | `wu.ac.at/universitaet/news-und-events/events` | economics | |
| **IHS** | `ihs.ac.at/news-and-events/events-calendar/` | economics, social science | |
| **Wolfgang Pauli Institute** | `wpi.ac.at/activities_view.php?s=event` | maths, physics | PHP |

Blocked/dead: `oeaw.ac.at` (Austrian Academy of Sciences) **403** on `/veranstaltungen`,
`/events` and homepage — a real loss. `fwf.ac.at` has no event calendar
(`/de/aktuelles/eventkalender/` 404). `meduniwien.ac.at` events page lists nothing.

**Residual risk**: a commercially-organised congress in a non-medical field — the analogue
of the Zahnmedizin one that only MAW had — would still be missed, since it belongs to no
university and MAW is medical-only.

### Final gap closure — everything below now has a source

| Item | Source |
|---|---|
| **Music discovery lane** (experimental electronic, non-club dance, world/jazz) | All open, all 200: `wuk.at/programm/` · `rhiz.wien` · `fluc.at/programm/` · `echoraum.at/programm/` · `brut-wien.at/de/programm` · `sargfabrik.at` · `szene.wien` · `chelsea.co.at` · `arena.wien/Home/Programm` · `grelleforelle.com/programm` · `werk.wien` · `reigen.at` · `jazzland.at` · `porgy.at` · `wienmodern.at` · `konzerthaus.at`. **Sourcing was never the hard part — only the ranking heuristic is, and that is a separate problem** |
| **Opera** | `volksoper.at/spielplan/` · `neueoperwien.at` · `sirene.at` — plus the blocked houses via aggregators below |
| **Philosophy / ethics / religion / society** | `kreisky-forum.org/veranstaltungen/` · `depot.or.at/programm` · `wienervorlesungen.at` (city lecture series) · `kalender.univie.ac.at` · `ihs.ac.at` |
| **Major spectator sport** | `eventim.at` · `ticketmaster.at` · `skrapid.at` (570 KB) · `fk-austria.at/teams/profis/spielplan` · `vienna-capitals.at/spielplan` |
| **Strasser Workout** | **Needs no scraper — it's a fixed recurring rule.** Michael Strasser, free public workout, **every Monday & Thursday evening, Arne-Carlsson-Park, 1090**, running since 2014, 200–400 participants. Social-media-only announcements, so encode the schedule directly |
| **Genuss-Festival** | `festival.genussregionen.at` — 8–10 May 2026, Stadtpark, free, 100+ producers. (`genuss-festival.at` / `genussfestival.at` are dead domains — earlier guesses were wrong) |
| **Bargain / resale** | `willhaben.at/iad/kaufen-und-verkaufen/marktplatz/tickets-4523` (200, 688 KB; robots names **no** Claude/anthropic agent — a subagent claimed otherwise, checked directly, false) + `aurena.at/auktionen` for goods |
| **Demonstrations** | **Verified negative — no public registry exists anywhere.** Austrian demos must be registered with the Landespolizeidirektion 48 h ahead, but the register is not published. `polizei.gv.at/wien/buergerservice/versammlungen/` is an info page with zero entries and puts `Anthropic-ai` + `Claude-Web` in a `Disallow: /` group. No wien.gv.at dataset, no Open Data entry. Partially caught indirectly via meinbezirk local news. **Don't re-investigate** |

### Blocked venues — and how each is still covered

Eight sites `Disallow: /` for ClaudeBot. None is a dead end: **open ticketing aggregators
list the same events** — `eventim.at`, `ticketmaster.at`, `wien-ticket.at`, `volume.at`.

| Blocked | Covered instead via |
|---|---|
| wiener-staatsoper.at | eventim · ticketmaster · wien-ticket · volume.at |
| theater-wien.at | same |
| **stadthalle.com** (major venue) | same |
| viennale.at | `wien.gv.at/kultur/sommerkinos` + member cinemas (Gartenbaukino, Stadtkino, Filmmuseum) |
| ra.co (Resident Advisor) | the venue list above — Grelle Forelle, Fluc, Werk, Chelsea, rhiz, Arena |
| **iwm.at** (Inst. f. d. Wissenschaften vom Menschen) | Kreisky Forum · Depot · Wiener Vorlesungen · univie |
| dorotheum.com | `aurena.at` |
| falter.at | wien.gv.at · meinbezirk · volume.at · vienna-events.com |

### The one residual ceiling — and its mitigation

Facebook-only acts (the Walletschek case) publish no feed of their own. **But they play at
venues.** With WUK, Sargfabrik, echoraum, rhiz, Reigen, Szene, Chelsea and the rest all
covered, such an act is caught the moment it books a listed room. Residual loss is limited to
gigs in unlisted private spaces.

## Coverage check — 9 real queries

Tested against sources; ✅ = a listed source has it.

| Query | Answer | Source |
|---|---|---|
| Karlsplatz festival, late July | Popfest Wien, 23–26 Jul, free, ~50 acts | ✅ volume.at |
| Kruder & Dorfmeister | Thu 20 Aug, Arena Open Air, €65, sold out | ✅ volume.at |
| Erotikmesse | 6–8 Feb, Marx Halle | ✅ volume.at |
| Haustiermesse | 28 Feb–1 Mar, Marx Halle, 240 exhibitors | 🟡 marxhalle.at |
| Zahnmedizin congress | 50th Öst. Kongress, 1–3 Oct, Hofburg | ✅ maw.co.at |
| Porgy & Bess next week | 1 show (8 Aug), then summer break to 3 Sep | ✅ porgy.at |
| Whisky festival Ottakringer | Vienna Whisky Festival, 17–18 Apr | 🟡 ottakringerbrauerei.at |
| Walletschek, 20 Jun | not listed anywhere machine-readable | ⛔ Facebook only |
| Albertina Sonderausstellung | Richard Prince, Helga Philipp, Die Welt im Fokus, +2 | ✅ albertina.at |
| *(added)* Emma Harner | Mon 29 Sep, Club Lucia 1080, **€26.50** | ✅ volume.at |
| *(added)* Vienna Comic Con | VIECC 2026 | ✅ wien.gv.at |
