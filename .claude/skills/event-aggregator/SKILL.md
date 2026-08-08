---
name: event-aggregator
description: Vienna event aggregator that syncs into Flo's Google Calendar so he stops missing park festivals, Grätzlfeste and one-off gigs happening next door. 110 scrapers feed a SQLite store; a digest ranks a day by inverse specificity. findings.md holds what Flo wants, which sites are scraped, the ranking model and the backlog. Use when Flo asks about the Vienna event aggregator, wants to resume this work, or asks which event sources are usable.
---

# event-aggregator

**Status: 110 scrapers built, 7 dead. ~11.3k events. Calendar sync not built.**

A TypeScript pipeline over Python scrapers. Node 24 runs the `.ts` files directly —
there is no build step, and `node:sqlite` means no runtime dependencies at all.

```sh
direnv allow          # or: nix-shell
npm install           # dev-only: typescript + @types/node
node src/cli.ts       # usage
```

- [findings.md](findings.md) — 1. what I want · 2. what sites to scrape · ranking model · backlog
- [event.schema.json](event.schema.json) — the one record shape every scraper emits

## Pipeline — `src/`

| | |
|---|---|
| `cli.ts` | `scrape` · `digest` · `rotate` · `merge` · `stats` |
| `db.ts` | SQLite schema (`events` / `scrapers` / `runs`), ingest, blacklist |
| `schema.ts` | `EventRecord` + validator, both driven by `event.schema.json` |
| `scrape.ts` | spawns a Python scraper, parses its stdout, validates |
| `rank.ts` | inverse-specificity scoring |
| `pool.ts` | bounded concurrency, results streamed as they land |
| `commands/` | one file per subcommand |

`node src/cli.ts scrape` takes `--all` (ignore cadence), `--seed` (ingest sample files
instead of fetching), `--dry`, `--jobs N`, and positional slugs.
`digest` takes `--date`, `--limit`, `--why`. `rotate` takes `--min-run`, `--all`.

## Scrapers — `scrapers/`

Still Python, and deliberately so: they are bespoke and disposable, and the seam
between the two languages is the JSON-per-line contract they already print on stdout.
Porting them happens one at a time, whenever one needs re-opening anyway.

- one dir per source: `scrape.py`, `meta.json`, `NOTES.md`, `scraper_example_result.json`
- `registry.json` — 117 buildable + 24 blocked
- `check.py <slug>` — validate a scraper and rewrite its example result
- `cadence.py` — measure density → cadence + horizon
- `lib/ea.py` — shared fetch/parse helpers
- builder agent: `.claude/agents/scraper-builder.md`
- `probes/probe.sh` — scrapeability prober

`blacklist.json` filters at read time — records are still scraped and stored.
`events.db` and `events.json` are gitignored.
