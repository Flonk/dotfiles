import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { deriveEnd } from "../db.ts";
import { EVENTS_JSON, SCRAPERS } from "../paths.ts";
import type { EventRecord } from "../schema.ts";
import { encodeNonAscii } from "../url.ts";

type Merged = EventRecord & { uid: string };

export function load(): Merged[] {
  const out: Merged[] = [];
  for (const slug of readdirSync(SCRAPERS).sort()) {
    const f = join(SCRAPERS, slug, "scraper_example_result.json");
    if (!existsSync(f)) continue;
    for (const r of JSON.parse(readFileSync(f, "utf8")) as EventRecord[]) {
      const uid = createHash("sha1")
        .update(`${r.source}:${r.source_id}`, "utf8")
        .digest("hex")
        .slice(0, 12);
      const end = deriveEnd(r);
      if (end) {
        r.end = end;
        r.extra = { ...(r.extra || {}), end_derived: true };
      }
      if (r.image) r.image = encodeNonAscii(r.image);
      out.push({ ...r, uid });
    }
  }
  return out;
}

export function main(): number {
  const recs = load();
  writeFileSync(EVENTS_JSON, `${JSON.stringify(recs, null, 1)}\n`, "utf8");

  const timed = recs.filter((r) => (r.start || "").includes("T")).length;
  const ends = recs.filter((r) => (r.end || "").includes("T")).length;
  const derived = recs.filter((r) => (r.extra || {})["end_derived"]).length;
  console.log(`${recs.length} records -> ${EVENTS_JSON}`);
  console.log(`timed starts ${timed} | end times ${ends} (derived ${derived})`);
  return 0;
}
