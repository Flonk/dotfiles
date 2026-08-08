---
name: event-aggregator
description: Placeholder for a Vienna event aggregator that syncs into Flo's Google Calendar so he stops missing park festivals, Grätzlfeste and one-off gigs happening next door. Currently EXPLORATION ONLY — no implementation exists. findings.md holds what Flo wants and which sites to scrape. Use when Flo asks about the Vienna event aggregator, wants to resume this work, or asks which event sources are usable.
---

# event-aggregator

**Status: scrapers being built. 1 of 117 done.**

- [findings.md](findings.md) — 1. what I want · 2. what sites to scrape
- [event.schema.json](event.schema.json) — the one record shape every scraper emits
- `scrapers/` — one dir per source. `registry.json` (117 buildable + 24 blocked),
  `check.py <slug>` (validate + write `scraper_example_result.json`),
  `cadence.py` (measure density → cadence + horizon), `lib/ea.py` (shared helpers)
- Builder agent: `.claude/agents/scraper-builder.md`
- `probes/` — `probe.sh` (scrapeability prober)
