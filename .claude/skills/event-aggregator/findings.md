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

## Output shape: lineup sections

The digest condenses whole categories into one-line lineups — reads like a festival bill
and collapses ~600 daily records to a scannable handful. Two so far: `Acts today`
and `Movies today`.

### `Acts today`

```
Acts today
Ed Sheeran · Megadeath · Bonobo · ...
```

Named "acts", not "music" — the section legitimately carries cabaret, dance and comedy,
which venue-based classification pulls in anyway.

Ordering is two-tier:

1. **Artists Flo follows on Spotify** — always first, regardless of size
2. **Everyone else** — descending by Spotify play count

So a followed 200-listener act outranks a stadium headliner. Tier 1 is the personalisation;
tier 2 is a fame prior standing in for "would he have heard of them".

**Blocker: there is no `artist` field.** The schema stores `title`, and venues conflate
artist with event name — `ROTZPIPN | ANTI CORNETTOS` is two bands, `BEHAVE!` is a club
night, `Diknu Schneeberger & Christian Bakanic Quartett` is two leads plus an ensemble
noun, `technolog` is a night not a person. Ranking by artist requires extracting artists
from titles first. Options, cheapest first: a per-source hint in `extra` where the site
already separates them; a title-splitting pass on the known separators (`·  |  &  ,  vs
feat.  presents  w/`); resolving each candidate against the Spotify search API and keeping
what matches. Unresolved names must still render — degrade to showing the raw title, never
drop a gig because the parse failed.

Needs Spotify: followed-artists list (`user-follow-read`) and per-artist popularity.
Play count is not exposed per user; artist `popularity` (0–100) is the available proxy.

### `Movies today`

```
Movies today
Drowning by Numbers · Kedi · OLDBOY · ... · The Odyssey (8 screens)
```

Ordering is **inverse ubiquity** — the opposite of `Acts today`. A film screening once, at
one repertory house, ranks above the blockbuster on eight screens, because the one-off is
the thing Flo would otherwise miss. This is signal 2 (rare / one-off) applied within a
category, and it needs no external API: screen-count is already in the data as
`COUNT(*) GROUP BY title`.

Blockbusters are not dropped — they sort last and carry a `(n screens)` suffix, so the
line still answers "is anything on that I'd want to see" without pretending Toy Story
isn't playing.

Title normalisation is required before grouping: the same film arrives as `The Odyssey` /
`Die Odyssee`, and as `Backrooms` / `Backrooms: Everything Must Go (Extended Version)` /
`Backrooms: Everything Must Go Edition (Extended Version)`. Match on a normalised key and
keep the shortest variant for display. German and English titles for the same film must
collapse to one entry, which regex alone will not do — needs a title-alias pass.

**Per-film payload.** Each entry carries: **image**, **1½-sentence blurb**, **rating**,
**genre**, **cinema + time**. Layout deferred, but the intended shape is dense and
3-column-ish, images in outer columns left and right.

Where each piece comes from:

| piece | source | state |
|---|---|---|
| cinema + time | already in the DB | ✅ have it |
| image | `image` schema field, per-site scrape | backlog item, see parser pass |
| blurb | TMDB `overview` | needs external |
| genre | TMDB `genres` | needs external |
| rating | TMDB `vote_average` | needs external |

Site descriptions are unusable as a uniform blurb, measured 2026-08-08:
`haydnkino` (223 records — the largest cinema source), `burgkino` and `filmcasino` carry
**none at all**; `admiralkino` averages 17 characters, `gartenbaukino` 30, `breitenseer`
38 — too short to be a blurb; `cinecenter` 677 and `filmarchiv` 682 — need trimming. A
uniform 1½ sentences cannot be assembled from that spread.

**TMDB is the approved integration** (Flo: *"TMDB is fine"*). One lookup keyed on
title+year yields `overview` (blurb), `genres`, `vote_average` (rating), `poster_path`
(consistent image), and the alternate-titles list that solves the German/English collapse
above — five requirements, one integration.

Rating renders bare as `8/10` — no source label, no provenance chrome.

Note this section only makes sense for the repertory tail: cinema is ★☆☆ with **routine
screenings excluded**, and inverse ubiquity is what implements that exclusion. With a
per-film payload this rich, the blockbuster tail should be cut rather than rendered with a
`(10 screens)` suffix.

### `Film festivals` — separate section

Festivals do **not** fold into `Movies today`. They are listed on their own, because they
are a different unit: a festival is a multi-day run to plan around, not a screening to
catch tonight. This is also what the ★☆☆ cinema rule already implies — *festivals and
special programmes only*, routine screenings excluded.

Eight sources already feed this: `rathausplatz` (45 — filmed concerts, see its meta note),
`volxkino` (15), `visitingvienna` (14, a festival directory), `wien_gv_sommerkinos` (11),
and `japannual` / `kinoamdach` / `slashfilmfestival` / `viennashorts` at **1 record each**
— those four emit one whole-festival record with a date range rather than a per-screening
breakdown, because off-season their sites publish only the edition dates. So the section
renders festival *runs*, not screenings, and needs the lead-time question answered:
`viennashorts` currently sits 9 months out (25–30 May 2027).

Note the sections described so far — `Acts today`, `Movies today` — are the **routine
daily** ones. Festivals, and anything else episodic, get their own treatment.

## Inverse specificity — the demotion model

Measured across the whole DB 2026-08-08: 9474 upcoming records (after blacklist) in 6583
distinct `(title, venue)` blocks. Two axes, both **demotions, never cuts**.

| axis | threshold | hits | action |
|---|---|---|---|
| run length | ≥ 8 occurrences | 93 blocks / 1475 records (15.6%) | rank way down |
| span | ≥ 91 days, non-permanent | 161 records | rank way down |
| permanents | `extra.permanent` | 67 | keep, rank low, **never cut** |

**Measure REMAINING, not total.** This is what makes both demotions self-repealing: a
22-night play sits demoted all season, then surfaces as last-chance when 2 dates are left;
a 144-day exhibition is wallpaper for 143 days and a must-see on its final weekend.

- *Run length needs no code.* The DB retains past events (345 of them), so any query
  filtered `start_at >= today` already returns remaining, not total. Verified: total and
  remaining are the same number by construction.
- *Span must use days-left, not days-long*, and **must exclude same-day events** — most
  records with an `end` are single-day events where `end` is just a finish time, span 0.
  They swamp the axis otherwise. Threshold that works: `span >= 30d AND days_left <= 21`,
  which surfaced 18 real closings including URSI FÜRTLER (1d left of 144), Institute of
  Queer Ecology (1d of 121), RICHARD PRINCE (8d of 121), Innovation Corner (8d of 187).

**Run length ≥ 8 conflates three different things** — do not demote blindly:

1. **Timetabled attractions** → demote. Planetarium repertoire (~19 shows, ~350 records),
   museum Führungen (NHM Narrenturm 65×, Über den Dächern Wiens 53×, MAK ×4, Konzerthaus
   backstage 32×), cinema multiplex runs, WKO `Gründungs-Webseminar` boilerplate.
2. **Theatre seasons** → keep, collapse to one entry with a date range. Josefstadt
   *Komödie der Verführung* 22×, *Hamlet* 10×; Volksoper *West Side Story* 16×,
   *Zauberflöte* 14×. 154 records. A play running 22 nights is 22 chances at one thing.
3. **Lecture / residency series** → keep. `Ringvorlesung Environment and Climate Research`
   14×, Porgy & Bess *Wednesday Night Prayer Orchestra* 8×, arthouse doc runs like
   *Mit Hasan in Gaza* 11×.

The discriminator is **whether attending twice makes sense**, not the count.

Caveat for whoever implements the scorer: permanents store `end_at IS NULL`. Treating null
as a 1-day span ranks the Albertina's permanent collection *above* a one-night gig. Handle
null-end explicitly.

Inverse specificity is a good axe for wallpaper but does not produce a digest on its own —
it cuts roughly 25%, not 95%.

### Perennial availability — a third axis

Distinct from run length. Flo on a swimming course: *"I dont really care about, I can do
that any day of the year."* On VHS: *"language courses are on all year, those we should
just filter."*

The signal is not "this repeats" but **"nothing is lost by missing it today"**. A course
block may only carry 8 dates and still be worthless, because an equivalent one starts next
month. Demote (or filter outright) standing offers: language courses, swimming courses,
fitness classes, recurring adult-ed intake.

Contrast with **annual events of scale** — Vienna Marathon: *"genuinely huge."* Once a
year, city-wide, unmissable. High run length is impossible for these, so they need no
special handling, but they must never be caught by a "sport = routine" rule.

### Incongruity — wanted, unsolved

The single most-liked result in testing was a WKO listing, *"Junge Wirtschaft Waldviertel
geht klettern!"* — a business-networking association going climbing. Flo: *"sounds
cringely amazing, AI wouldn't understand. that's peak reverse specificity."*

What makes it land is **category mismatch**: a business-chamber source emitting a sport
activity. That is in principle detectable as source-group × activity-type disagreement,
but treat it as a hypothesis, not a solution — the same rule would promote every mislabelled
record in the DB, and most mismatches are just bad metadata rather than comedy.

**Known tension, unresolved:** this event is in 3573 Rosenburg-Mold, Waldviertel. Any
Vienna geography filter removes it. The most-wanted result in testing is out of scope by
the rules already agreed. Related: the train-ride rule and the unsolved "magnitude"
question below.

Bieryoga at Ottakringer is the counter-case and needs no new machinery: fine once, spam
weekly, and run-length demotion plus the rotation diff already handle it — the diff tells
you when it *enters* the rotation, which is the only moment it is news.

## Blacklist

`blacklist.json` — excluded at **read time only**, so records are still scraped and stored
and removing an entry brings them straight back with no re-scrape. Supports `sources`
(by slug), `venues` and `titles` (substring). `db.blacklist()` / `db.blacklisted()`.

Currently excluded: **`srs`** (Spanische Hofreitschule) — 1470 records, 13% of the entire
DB, six guided tours repeating daily forever.

## Rotation change detection

For fixed-repertoire sources — Planetarium, Urania Sternwarte, museum tour programmes,
Konzerthaus backstage — the useful interaction is not listing them daily but being told
**when the rotation changes**. Demote the 26 repeats, alert on the transition.

Already in place, no new schema needed: `events.first_seen`, `events.gone`, and the `runs`
table logging `n_new` / `n_gone` per scrape. Verified by simulation — dropping a show and
adding one reported exactly:

```
entered:  + Der Mond - Unser kosmischer Nachbar   12 dates from 2026-08-14
left:     - EXO:Aliens                            26 dates dropped
```

**Alert on new distinct TITLE, not new records.** `n_new > 0` also fires on ordinary
schedule extension — the Planetarium publishing January dates for a show already running
is not a rotation change. Group by title before alerting.

Needs ≥2 successful runs of a source before there is anything to diff.

### Rotation diff

**What left rotation and what came on**, restricted to blocks with **run length > 2**
(below that it is not a rotation, it is just an event). This is the mechanism that makes
demoting the repertoire safe — nothing new slips past while its 26 repeats sit ranked down.

Implemented as `rotate.py`, on demand. Cadence (weekly, start-of-week, whatever) is a
scheduling question, deliberately deferred — the mechanism does not care when it is run.

## Known-unsolved

- **The music discovery lane.** Flo: *"Specificity is important but I don't believe you can
  find a heuristic for this."* Kurdish jazz was one of his best concerts ever; no genre tag
  predicts that. Don't fake a solution.
- **How to measure "magnitude"** for the train-ride rule. No source field maps to it.
- **Facebook-only events are unreachable.** Walletschek Laien Akkordeon Ensemble is a real
  ensemble with real gigs listed nowhere machine-readable. Permanent coverage ceiling.
- **No retrospect** unless history is captured from day one.
- **Dedupe is mandatory** — Popfest appeared in 5 sources at once.

## Backlog

### Nightly parser pass

Work that means re-opening scrapers, batched into an overnight agent run like the original
build. Ordered by damage done.

1. **`volume_at` has no start times.** 0 of 1304 records carry one — the biggest source and
   the main gig listing in town is date-only, so ~25 real gigs a day can't be placed in a
   calendar. Highest priority: a missing `end` is cosmetic, a missing `start` makes the
   record unusable.
2. **Cinema scrapers should capture `image`.** Schema field added (optional, absolute URL).
   Quality bar is deliberately low — poster, production still, anything representative;
   only a site logo or placeholder is wrong. Availability varies per site: `gartenbaukino`
   has JSON-LD `image`, `votivkino` has `og:image`, `filmcasino`/`stadtkinowien` have plain
   `<img>` stills, `haydnkino` uses a predictable `/FilmImg/<slug>.jpg` path, `topkino`
   needs a real selector because its first `<img>` is the logo. Most posters live on the
   detail page, not the listing — but several cinema scrapers already fetch detail pages
   for price/runtime, so it is close to free for those.
3. **End times where the site publishes them.** ~6100 timed records have no `end`. Top
   gaps: `srs` 1470 (fixed-duration tours, easy), `wko` 1451 (low priority, nationwide),
   `wien_ticket` 650, `haydnkino` 195, `porgy` 185, `wien_gv_at` 169 — top 6 covers 4120.
   275 are already derived at merge time from runtimes the scrapers captured in `extra`.
4. **Geography on `volume_at` and `wko`.** Both are Austria-wide, not Vienna. `volume_at`
   has 0 district and `city='Wien'` on 920 of 1304 (correct — null when out of town, so
   usable as a filter). `wko` fills district on 11% of 1800. Without this a Vienna filter
   can't tell "not Vienna" from "unknown", which already produced a false negative on
   Diknu Schneeberger.
5. **Cadence sanity-check on thin samples.** `admiralkino` (7 records) and `nonstopkino`
   (8) were measured onto `monthly`, which is wrong for a cinema and will go stale between
   runs. The density heuristic mis-reads low sample counts as low churn.
6. **`kindermuseum` silently skips hub pages** when ZOOM's flaky server hangs, so yield
   varies 5–6 per run and `min_records` can't distinguish "slow" from "broken".

### Missing STEM coverage — new sources needed

Congresses/conferences are ★★★ and STEM is not fully covered. Audited 2026-08-08 against
the 10 institutional calendars actually scraped. Ordered by value.

1. **ÖAW is the biggest single loss.** `oeaw.ac.at` 403s sitewide, already in
   `registry.json` as blocked. The Academy runs **IQOQI** (quantum optics), the **Space
   Research Institute** and acoustics research — none of it visible. Worth retrying with a
   different fetch approach before writing it off; a 403 on a browser UA is not the same
   as a robots ban.
2. **`univie` does not deliver what its note claims.** `findings.md` said "all fields incl.
   philosophy, linguistics", but live output is financial econometrics, media law,
   Byzantine studies and a campus tour — 6 of 14 sampled records were the same
   Byzantinistik congress. The central TYPO3 calendar does **not** aggregate faculty
   colloquia; physics/chemistry/astronomy talks live on per-faculty pages. Either scrape
   those separately or stop claiming the coverage.
3. **No source at all, not even a blocked entry:**
   - **Chemistry** — no dedicated calendar anywhere in the registry
   - **Astronomy / astrophysics research** — the `planetarium` scraper's 532 records are
     public shows, not colloquia; Univie's Institut für Astrophysik is unscraped
   - **Vetmeduni Wien** — veterinary medicine, absent from the registry entirely
   - **AIT** — Austria's largest non-university research institute
   - **CeMM, IMBA, GMI** — the other Vienna BioCenter institutes; only IMP is scraped
4. **MedUni Wien** events page lists nothing, so clinical medicine outside MAW's
   commercial congresses is uncovered. Already noted as blocked; recheck periodically.

Sanity check on the ★★★ case: a **marine mammal** congress would be caught (NHM). A
**chemistry** congress or a **quantum optics** talk would not.

### Missing categories — new sources needed

Probed across the whole DB 2026-08-08. Ordered by priority × how bad the gap is.

1. **Participatory sport — ★★★ and effectively uncovered.** Highest-enthusiasm category in
   the priority table. 68 title matches and nearly all noise: Aperol Yoga, Bieryoga ×2, an
   Aurena camping-gear auction, a WKO networking climb. Genuine hits: one `meinbezirk`
   swimming course and `vienna_marathon`. **Missing entirely**: running-race calendar
   (Vienna has dozens beyond the marathon), parkrun, climbing gyms, sport clubs, public
   swimming programmes. Also still undone: `findings.md` says to encode Strasser Workout's
   Mon/Thu schedule as a fixed rule since it is Instagram-only — that has not been written.
   Filter out perennial course offerings per the availability axis above.
2. **VHS Wien — the largest reachable source not scraped.** Austria's biggest adult-ed
   provider. Already scraped *by accident*: `planetarium-wien.at` redirects to
   `vhs.at/de/e/planetarium`, and that one slice alone yields **532 records**. The rest —
   ~20 Volkshochschulen, lectures, workshops — is untouched, same site and same parser
   shape, already proven. **Must filter perennial courses** (language, fitness) or it will
   flood everything.
3. **Board games / gaming — zero records out of 11,289.** Total blind spot. No Spielefest
   (named in the priority table under trade fairs), no board-game cafés, no LAN/e-sport,
   no pen-and-paper. Flo: *"would be great to know."*
4. **Food & drink — ★★☆ with 31 hits and two sources**, one of which is a brewery. Flo:
   *"I dont mind a lot of food"* — so err toward more sources, not fewer. Missing: Whisky
   Festival (named as a want, no scraper), Heurigen calendar, tastings, food markets.
5. **Büchereien Wien** — 39 branches, readings and events, not scraped. The Hauptbücherei
   surfaces only because `meinbezirk` wrote about its rooftop cinema.
6. **Grätzlfeste / Straßenfeste — single point of failure.** 78 hits, **67 from
   `wien_gv_at` alone**. This is the project's original trigger. If that one listing thins
   out, the thing this was built for goes quiet — and the canary will not catch it,
   because the scraper still returns plenty of other events. Needs a second source.
7. **Queer / activism** — 24 hits, no Regenbogenparade/Pride source.
8. **Markets** — 62 hits, adequate for flea markets (ranked backlog anyway), but
   Christkindlmärkte will matter in December.

### Migrate to a TypeScript project

Flo, 2026-08-08: *"migrate to a typescript project (with npm nodejs package.json .envrc
shell.nix)"*. Today everything is stdlib Python run through `nix-shell -p python3`, chosen
because scrapers had to be disposable. That tradeoff is spent — the pipeline is now the
part that grows (calendar sync, TMDB/Spotify enrichment, digest rendering), and all three
have better libraries on node.

Two halves, and they are independent:

1. **Pipeline** (`db.py`, `run.py`, `digest.py`, `rotate.py`, `merge.py`) — ~700 lines,
   no HTML parsing, all the logic worth type-checking. Port this first; the schema is
   already JSON Schema, so record types can be generated rather than hand-written.
2. **110 scrapers** — each is a bespoke regex/JSON parser. Porting them is 110 rewrites
   with 110 chances to regress a working source, and buys nothing on its own. Do it
   source-by-source, on the next occasion each one needs re-opening anyway (see the parser
   pass above), not as a big bang.

So the interim state is intentional: a TS pipeline that shells out to Python scrapers over
the JSON contract they already emit on stdout. The contract is the seam — it is what makes
the mixed state safe rather than sloppy.

Skeleton wanted: `package.json`, `tsconfig.json`, `shell.nix` (node + python3, since both
are needed during the interim), `.envrc` for direnv, and `EA_DB` still honoured so the
existing `events.db` carries over untouched.

## Still needed from Flo

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
