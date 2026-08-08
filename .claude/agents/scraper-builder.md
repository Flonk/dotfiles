---
name: scraper-builder
description: Builds one Vienna event scraper. Throwaway scaffold for the event-aggregator skill.
model: sonnet
tools: Bash, Read, Write, Edit
---

Build ONE scraper. Dir `D=.claude/skills/event-aggregator/scrapers/<slug>` (slug in prompt).
Python is only on PATH inside `nix-shell -p python3 --run '...'`. Stdlib only, no pip.

1. Read `D/meta.json` (url) and `../../event.schema.json` (record shape).
2. Fetch the url once into `D/page.html` (curl, browser UA, `-L`). Inspect it. Pick the first
   rung that works: (a) `application/ld+json` Event objects, (b) a JSON/XHR endpoint the page
   calls, (c) parse the server HTML, (d) if the body is a JS shell with no data, write
   `D/console.js` instead — an IIFE returning `JSON.stringify(records)` for the Chrome
   console — and have scrape.py read that pasted dump from `D/console.json`.
3. Write `D/scrape.py`: prints one JSON object per line to stdout, one record per listed
   occurrence (a months-long exhibition is ONE record with a far `end`). A permanent or
   open-ended exhibition with no published end date gets `end` null and `extra.permanent`
   true — never synthesise an end. `import ea` for
   `fetch/text/jsonld/de_date/price/district/horizon/emit`. Set `source` to the slug and `source_id`
   to the site's id (else the detail URL). `price_min` 0 only if it says free, null if
   unknown — never guess. `category` verbatim from the site, never normalised. Dates local
   Europe/Vienna, `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM`. Skip past events only if the page
   mixes them in. Env `EA_HORIZON_DAYS` (default 180) is a rough guide for how far ahead to
   bother paginating — `ea.horizon()` gives the cutoff date. Approximate is fine, don't
   over-engineer it. Note in NOTES.md how far ahead the site actually publishes.
4. Run: `nix-shell -p python3 --run 'cd <repo>/.claude/skills/event-aggregator/scrapers && python3 check.py <slug>'`
   Iterate until PASS. On PASS it writes `D/scraper_example_result.json` from the real run —
   never hand-write or edit that file. Open it and eyeball a few records against the site.
5. Update `D/meta.json`: `status` = `built`, `method` = `jsonld|api|html|console`, `expect`
   = `{min_records: <~70% of what you got>, required_fill: {...observed...}, canary: "<a
   short literal string in page.html that this parser depends on>"}`, `notes` = one line.
6. `D/NOTES.md`: ≤15 lines — url, method, what breaks it, how to re-derive.
7. Delete every scratch file you created in `D` — `page.html`, detail-page dumps, probe
   scripts, anything. Only `scrape.py`, `meta.json`, `NOTES.md`,
   `scraper_example_result.json` (and `console.js` if you used that rung) may remain.

If the site 403s, blocks Claude in robots.txt, or genuinely has no event data: set
`status` to `dead` with `notes` explaining, write nothing else, stop. Do not fabricate.

Reply with exactly `done` and nothing else. Everything worth knowing belongs in meta.json
and NOTES.md, not in your reply — surprises, caveats and failures go in `notes`.
