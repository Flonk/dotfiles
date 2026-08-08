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

## Improving a scraper re-keys its records

Measured 2026-08-08, right after `volume_at` gained start times. The ingest reported **873
records gone** — alarming until you look: 842 were `volume_at`, and **100% of them were
still live under a different id**. Zero actually disappeared.

The cause is the composite id, `source-source_id-start`. Give a record a start *time* where
it previously had only a date and `start` changes, so the id changes: the old row is
soft-deleted and a new one inserted. The gone rows had `timed=0`, the live rows `timed=842`
— exact correspondence.

Nothing to fix, but two consequences to know:

- **`first_seen` resets** on the re-keyed rows, because they are genuinely new inserts. So
  `rotate.py` reports them as newly *entered* rotation — 11 volume_at runs showed up as new
  the first time. That is an artefact of the improvement, not a real repertoire change.
  Expect one noisy rotation report after any scraper gains date precision, then silence.
- **It is one-time per improvement.** Not worth engineering around; worth not misreading.

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

1. ~~**`volume_at` has no start times.**~~ **Fixed 2026-08-08: 0 → 842 of 1304 (65%).**
   The listing markup really is date-only, but the detail pages carry a
   `<div class="meta__time">` block with `Beginn: HH:MM Uhr` and/or `Einlass: HH:MM Uhr`.
   A second threaded pass over every detail URL now fills `start` (Beginn preferred,
   Einlass as fallback), `address` 881, and `district` 656 — all 656 inside 1010-1220, none
   fabricated. `city` stays at 920, and the null-vs-Wien split is still deliberate: volume.at
   is Austria-wide, so null means out of town.

   The remaining 35% genuinely publish no time; ~65-70% is the ceiling, not a floor to push
   on. `end` stays null everywhere — the site never publishes one on any page.

   `required_fill` is set conservatively **below** the observed rate because the sandbox's
   shared egress was dropping bursts of connections during the build (up to 80% of detail
   fetches in the worst window). The scraper degrades gracefully under that rather than
   crashing or fabricating, and the variance is documented in its NOTES.md.
2. **Cinema scrapers should capture `image`.** **Batch 1 done 2026-08-08** — gartenbaukino,
   votivkino, filmcasino, stadtkinowien, topkino, haydnkino all at **100% image fill**, by
   four different routes: JSON-LD `image`, a card's `background-image:url(...)`, the film's
   own detail page fetched concurrently, and a slug-derived path. Runtimes came with it, so
   those six now yield **410 derived end times** — the pipeline builds `end` from `extra`
   rather than the scraper guessing. Two residues: `gartenbaukino` publishes no running
   time anywhere, and `haydnkino` is slow and flaky under load, so its day-list fetches had
   to become concurrent with per-fetch timeouts and one retry — noted in its meta so nobody
   "fixes" it back to sequential.

   **Batch 2 done too** — admiralkino, bellariakino, breitenseer, burgkino, cinecenter,
   filmarchiv, filmmuseum, nonstopkino, schikaneder: **358/360 images**, another 314
   derived end times. So all 17 cinemas now carry a poster or still: **872 image URLs**.

   **Spot-checked rather than trusted**: 30 sampled URLs across all 17 cinemas, and 28
   returned a real `image/*` response. The two exceptions were both instructive:

   - `admiralkino` emits `http://` in its own `og:image`, and port 80 is `EHOSTUNREACH`
     while the identical `https://` URL returns the image. Rewritten in the scraper. (The
     site went fully down mid-check, so the fixed sample has not been regenerated yet —
     check.py correctly refuses to overwrite a sample on failure, so nothing was lost.)
   - 59 of the 872 URLs carry raw UTF-8 in the path (`..._©-El-Deseo.jpg`), 49 of them
     `votivkino`. Browsers and node's `fetch` both handle that fine — measured, not
     assumed — so it is hygiene, not a live breakage: Python's urllib raises on it and
     `format: uri` wants it encoded. Normalised centrally in `src/url.ts` so future
     sources get it for free. `encodeURI` is the wrong tool there; it escapes `%` too and
     double-encodes anything already correct.

   Two sources publish no runtime at all (`gartenbaukino`, `filmmuseum` — the latter's
   records are series spanning many films), and one admiralkino photo exhibition publishes
   a literal "1524 Minuten". All three are left alone: the pipeline's 1-600 minute bound
   stops the last one becoming an end time.

   Original notes: schema field added (optional, absolute URL).
   Quality bar is deliberately low — poster, production still, anything representative;
   only a site logo or placeholder is wrong. Availability varies per site: `gartenbaukino`
   has JSON-LD `image`, `votivkino` has `og:image`, `filmcasino`/`stadtkinowien` have plain
   `<img>` stills, `haydnkino` uses a predictable `/FilmImg/<slug>.jpg` path, `topkino`
   needs a real selector because its first `<img>` is the logo. Most posters live on the
   detail page, not the listing — but several cinema scrapers already fetch detail pages
   for price/runtime, so it is close to free for those.
3. **End times where the site publishes them.** **Largely done 2026-08-08.**
   `wien_ticket` 642/652 (98%), `wien_gv_at` 559/728 (77%, and it already did this
   correctly — the gap is genuine, its structured `to` equals `from`), plus 410 derived
   from cinema runtimes. `srs` was skipped on purpose: it is blacklisted, so filling
   1470 end times there is work nobody would ever see.

   **`porgy` is a deliberate zero.** The only end-shaped field on the site is the `.ics`
   export's `DTEND`, and it is *always* exactly `DTSTART + 2h00m` across every id checked,
   matinees and late shows alike — a CMS default, not data. Left null for all 186.

   ### The occurrence-end vs run-end trap

   `wien_ticket` first came back at 99% fill, which was too good. 198 of those ends were
   over twelve hours long, and the worst claimed a 14:00 performance ended **fourteen
   months later** — the scraper had taken the second date in the listing's info text,
   which is the *production's* last date, and attached it to a single performance.

   Two things made this worse than a cosmetic error. Ranking reads span from
   `end - start`, so every affected show scored as a 400-day run and got demoted 45
   points. And the digest's "currently running" clause (`start <= day AND end >= day`)
   would have put one 14:00 musical on **every single day for fourteen months** — the
   exact wallpaper the ranking model exists to suppress, manufactured by bad data.

   The tell is structural and worth reusing: **a timed start with a date-only end is
   almost always a run, not an occurrence.** It cannot be a blanket pipeline rule, though,
   because that shape is exactly what a legitimate exhibition record looks like — one
   record, far end. The distinction is semantic, so it has to be fixed per source, where
   we know whether the source lists productions or performances.

   Removing the bogus end also *raised* the real fill from 90% to 98%: the enrichment pass
   only filled records whose `end` was still null, so the wrong value had been shadowing
   the right one. A field that is wrong is worse than a field that is missing, twice over.

   Original notes: ~6100 timed records had no `end`. Top
   gaps: `srs` 1470 (fixed-duration tours, easy), `wko` 1451 (low priority, nationwide),
   `wien_ticket` 650, `haydnkino` 195, `porgy` 185, `wien_gv_at` 169 — top 6 covers 4120.
   275 are already derived at merge time from runtimes the scrapers captured in `extra`.
4. ~~**Geography on `volume_at` and `wko`.**~~ **Done 2026-08-08.** `volume_at` covered
   above. For `wko`: `city` 67%, `address` 0% → 11%, and the important part is that the
   1800 records now decompose honestly into **199 identifiably Vienna, 1013 identifiably
   elsewhere** (Graz, Zagreb, Barcelona — verbatim), **444 online** (the site says
   "Webinar"/"MS Teams", which is not a place and is correctly left null), and **144
   genuinely unknown** foreign trade fairs whose only location is unparseable prose like
   "JIExpo Kemayoran, Jakarta".

   So district staying at 11% was never a fill failure — it is the truth. Only 199 of
   these events are in Vienna. That is the number the filter needed.

   Two judgement calls worth keeping: the agent **declined** to infer `city` from the
   detail page's free-text venue name, because that field mixes institution names, city
   names and full addresses indistinguishably and would have stuffed an org name into
   `city`. And it scoped detail fetches to only the ~450 ambiguous records after
   discovering wko.at rate-limits above ~10-15 req/s — a naive fetch-all design ran
   230-380s and was impolite; the scoped one runs in **32s**.
5. ~~**Cadence sanity-check on thin samples.**~~ **Fixed 2026-08-08.** `admiralkino` (7
   records) and `nonstopkino` (8) had been measured onto `monthly` — wrong for a cinema,
   and it would go stale between runs. Two causes, both now addressed in `cadence.py`:

   - **Density conflates "few events" with "short window".** A cinema listing 7 films over
     the next 3 days is not low-churn; its whole programme is replaced within the week.
     Added `window_cadence(reach)`, where `reach` is how far ahead the published programme
     extends. It follows `end` where there is one — otherwise a museum whose every
     exhibition *started* in the past looks like a one-day window, which is how the first
     version of this rule shoved `belvedere` and `technischesmuseum` to daily.
   - **The group prior is now a floor.** One snapshot can show that a source is busier than
     its kind usually is; it cannot show the opposite, because a quiet week at a cinema is
     a quiet week, not a cinema that stopped turning over. Measurement may tighten the
     prior, never loosen it. This is what stops `stadtkinowien` (31 records reaching past
     45 days) from relaxing to monthly.

   Net effect: **25 cadence changes, every one a tightening.** The big aggregators move to
   daily where they belong (`wien_gv_at`, `eventbrite`, `wien_ticket`, `meinbezirk`,
   `ticketmaster`), music venues and academic calendars to weekly. `cadence.py --dry` now
   reports what would change without writing.
6. ~~**`kindermuseum` silently skips hub pages**~~ **Fixed 2026-08-08.** A hub page that
   still fails after three tries now **raises** instead of returning nothing, so scrape.py
   exits non-zero and the run is recorded as a failure. The point is the asymmetry: a run
   that fails leaves the previous records alone, whereas a run that quietly returns
   five-sixths of the data marks the missing sixth `gone`. Failing loudly is the safe
   direction, and `min_records` never had to tell "slow" from "broken" in the first place.

   The same reasoning is now enforced pipeline-wide — see the record floor in
   `src/commands/scrape.ts`, which fails a scrape that comes back below
   `meta.expect.min_records` rather than ingesting a partial harvest.

### Missing STEM coverage — new sources needed

Congresses/conferences are ★★★ and STEM is not fully covered. Audited 2026-08-08 against
the 10 institutional calendars actually scraped. Ordered by value.

1. **ÖAW — partly solved 2026-08-08. The 403 is per-host, not per-organisation.**
   `oeaw.ac.at` and `oeaw.ac.at/en/events` still 403 on a browser UA, but the institutes
   sit on their own hosts and answer fine:

   | host | status | note |
   |---|---|---|
   | `imba.oeaw.ac.at/events` | **200** | while `imba.oeaw.ac.at/` itself 403s — the block is path-scoped |
   | `cemm.at` | 200 | |
   | `gmi.oeaw.ac.at/news-events` | 200 | |
   | `astro.univie.ac.at` | 200 | the astronomy gap, directly |
   | `physik.univie.ac.at` | 200 | |
   | `vetmeduni.ac.at/…/veranstaltungen` | 200, JSON-LD | |
   | `ait.ac.at/news-events` | 200, JSON-LD | |

   None of these disallow ClaudeBot. So the Academy's central calendar stays out of reach,
   but the research that was invisible — quantum biology, plant genomics, astrophysics — is
   reachable one institute at a time. The remaining true loss is IQOQI: `iqoqi-vienna.at`
   did not resolve at all and needs a fresh URL.
2. **`univie` does not deliver what its note claims.** `findings.md` said "all fields incl.
   philosophy, linguistics", but live output is financial econometrics, media law,
   Byzantine studies and a campus tour — 6 of 14 sampled records were the same
   Byzantinistik congress. The central TYPO3 calendar does **not** aggregate faculty
   colloquia; physics/chemistry/astronomy talks live on per-faculty pages. Either scrape
   those separately or stop claiming the coverage.
3. **No source at all** — mostly closed 2026-08-08:
   - **Vetmeduni Wien** — **built**, 18 records, publishes ~4 months out
   - **AIT** — **built**, 3 records. The listing page has no server-rendered items and no
     Event JSON-LD despite what the tier note claimed; the data is behind the jQuery
     "load more" AJAX endpoint
   - **Univie Fakultät für Physik** — **built**, 2 records. Trap worth remembering: the
     date chip on the news list is the *article's publish date*, not the event date — the
     real start, end and venue live in the free-text teaser
   - **Univie Institut für Astrophysik** — **dead for now.** Both the colloquium and
     institute-seminar pages are accordions of *past* talks; newest is 17.07.2026. The
     institute is between semesters and has not posted WS26/27. Recorded, not faked, with
     re-derivation notes (institute-seminar dates are explicit `DD.MM.YYYY`; kolloquium
     dates are "Weekday Month Day" with no year and need position-based inference)
   - **CeMM, IMBA, GMI** — the other Vienna BioCenter institutes, in flight
   - **Chemistry** — still nothing

   Yields here are small by nature — an institute running one colloquium a week *should*
   return a handful of records. The agents were told not to pad, and didn't.
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
   Probed 2026-08-08: `laufkalender.at` and `laufen.at` **do not resolve**, so there is no
   running-race calendar to scrape. `parkrun.co.at` answers 200 but its **robots.txt says
   in words: "We request that automated scraping does not take place"**, and disallows
   `/results/` and `/*/futureroster` — precisely where the dates are. parkrun.com/scraping
   repeats it. Not built, same treatment as vhs.at. What is left: `vienna-marathon.com`
   (already scraped), `wienersportstaetten.at`, and `wien.gv.at/freizeit/baeder/` for
   public swimming — the last being exactly the perennial case to filter, not surface.

   **So this category is still the biggest genuinely uncovered want**, and it is not for
   lack of trying: the two obvious calendars are dead domains and the third refuses us.
2. ~~**VHS Wien — the largest reachable source not scraped.**~~ **Dead: vhs.at disallows
   ClaudeBot.** Probed 2026-08-08 — `vhs.at/robots.txt` carries an explicit
   `User-agent: ClaudeBot / Disallow: /` (alongside GPTBot, Google-Extended and
   meta-externalagent). Not a 403 to work around; a stated refusal. Do not build it.

   **This implicates a scraper we already run.** `planetarium-wien.at` redirects to
   `vhs.at/de/e/planetarium`, and `scrapers/planetarium/scrape.py` fetches
   `www.vhs.at/de/e/planetarium/veranstaltungen` directly — 532 records, the 7th largest
   source. It was built before anyone checked the *destination's* robots.txt rather than
   the redirecting domain's. **Flo's call**, so it has been left running and its data left
   in place; the options are to drop the source (−532 records, and the Planetarium goes
   dark) or to keep it knowingly. Flagging, not deciding.

   General lesson: **check robots.txt on the host you actually fetch, after redirects.**
   `vienna.at` disallows ClaudeBot too, and was on the candidate list.
3. **Board games / gaming — was zero records out of 11,289. Partly closed 2026-08-08, and
   worth being honest about how partly.**

   The dedicated sources are simply gone: `spielefest.at`, `spielbar.wien` and
   `tabletop.at` **do not resolve**. So the only route is aggregators, and there we got:

   - **`viecc`** — Vienna Comic Con, **built**. One record, and one is correct: it is a
     single annual two-day convention with no archive to paginate (21-22 Nov 2026).
   - **`meetup_wien`** — **built, 43 records**, a new source shape for us (Next.js
     `__NEXT_DATA__` SSR blob). Note the agent did *not* use the `?location=` query URL
     from its brief — robots disallows it — and found a path-based city page instead.
     Only publishes ~4 weeks out; going deeper needs the disallowed GraphQL API.
   - **`eventbrite`** — a board-games feed added alongside all-events. **549 → 706
     records**, all 706 with unique ids, dedupe verified.

   **The eventbrite caveat matters.** `board-games/` is not a category filter at all — it
   is a full-text search over the same city-wide index, and the agent proved it by probing
   `gaming/`, `tabletop-gaming/`, `video-games/` and `hobbies/` and finding all five report
   an identical `object_count: 1017`. So most of the +157 are ordinary Vienna events that
   fuzzy-matched "game", not gaming content. It does surface genuine finds the all-events
   ranking never returns — **3W6 Con 2026**, a trading-card festival, a chess meetup — but
   `category` stays verbatim, so nothing downstream can classify these as gaming without
   title matching. The events are now present to filter from; they are not pre-labelled.
4. **Food & drink — better covered than the original probe suggested.** The 31-hit count
   came from a German-only regex; `eventbrite` alone already carries **28 records tagged
   "Food & Drink"** in its own category vocabulary (wine tastings, Heurigen evenings,
   food-market quizzes). The gap is narrower than recorded — what is genuinely missing is
   the Whisky Festival, a Heurigen calendar and food markets as *dedicated* sources, and
   probing found no Heurigen or whisky calendar that resolves. Flo: *"I dont mind a lot of
   food"*, so err toward more sources when one turns up.

   Method note worth keeping: **probe regexes must cover both languages and the source's
   own category labels.** Searching `weinverkostung|heuriger` while the source tags things
   "Food & Drink" reports a blind spot that isn't there.
5. ~~**Büchereien Wien**~~ **Built 2026-08-08 — 253 records, the biggest single win of the
   night after volume_at.** The page itself is a DNN shell with no data; the real feed is
   a JSON file at `Portals/0/Files/stb_va/stb_va.json` behind a DataTables widget.
   Publishes ~6 months ahead. 100% start times, 92% address and district, enriched by
   fetching the ~22 branch pages. `price_min` is only 3% — set solely where the free text
   literally says *kostenlos*/*gratis*, null otherwise, rather than assuming a library
   event is free.
6. **Grätzlfeste / Straßenfeste — single point of failure.** 78 hits, **67 from
   `wien_gv_at` alone**. This is the project's original trigger. If that one listing thins
   out, the thing this was built for goes quiet — and the canary will not catch it,
   because the scraper still returns plenty of other events. Needs a second source.
7. **Queer / activism** — 24 hits, no Regenbogenparade/Pride source.
8. **Markets** — 62 hits, adequate for flea markets (ranked backlog anyway), but
   Christkindlmärkte will matter in December.

### Migrate to a TypeScript project — pipeline done 2026-08-08

Flo, 2026-08-08: *"migrate to a typescript project (with npm nodejs package.json .envrc
shell.nix)"*. Everything was stdlib Python run through `nix-shell -p python3`, chosen
because scrapers had to be disposable. That tradeoff is spent — the pipeline is now the
part that grows (calendar sync, TMDB/Spotify enrichment, digest rendering).

Two halves, and they are independent:

1. **Pipeline** — **done.** `db.py`, `run.py`, `digest.py`, `rotate.py` and `merge.py` are
   gone, replaced by `src/` (see SKILL.md). Node 24 runs `.ts` directly, so there is no
   build step, and `node:sqlite` means **zero runtime dependencies** — typescript and
   @types/node are dev-only. `EA_DB` still honoured; the existing `events.db` carried over
   untouched via an `ALTER TABLE` for the new `image` column.
2. **110 scrapers** — still Python, deliberately. Each is a bespoke regex/JSON parser;
   porting them is 110 rewrites with 110 chances to regress a working source, and buys
   nothing on its own. Do it source-by-source, whenever one needs re-opening anyway (see
   the parser pass above), not as a big bang.

The seam is the contract the scrapers already spoke: one JSON record per line on stdout.
Nothing about a scraper had to change.

**Verified against the Python implementation before deleting it**, on a copy of the live
DB: `digest` output byte-identical, `rotate` identical, `merge` identical (11,292 records,
same timed/end/derived counts), and a seeded ingest of 607 records agreeing on every data
column including `extra`.

Two deliberate residues:

- **13 hash mismatches out of 607.** The change hash is built from a `json.dumps` of the
  field list, and Python prints a float `15.0` where JS prints `15`. `price_min` is the one
  float column, so `pyFloat` renders it Python-style — which fixes the 5410 records whose
  scraper emitted a float and breaks the 13 (all `depot`) that emitted an int literal.
  Cost of a mismatch is one inflated `n_changed`, nothing more; `first_seen` is untouched,
  so rotation detection is unaffected.
- **Two validators.** `src/schema.ts` serves the pipeline, `scrapers/check.py` serves the
  builder agents. Both read `event.schema.json`, so they cannot drift on the schema itself,
  only on how strictly they read it. Collapsing them would mean making the agents depend on
  node, which is not worth it.

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
