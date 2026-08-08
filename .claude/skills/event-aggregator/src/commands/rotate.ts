import * as db from "../db.ts";
import { norm } from "../rank.ts";

export const MIN_RUN = 3;

export type RotateOpts = { slugs: string[]; minRun: number; all: boolean };

type Block = { title: string; venue: string; dates: string[]; firstSeen: string };

function blocks(conn: ReturnType<typeof db.connect>, slug: string, gone: boolean) {
  const out = new Map<string, Block>();
  for (const r of db.all(
    conn,
    "SELECT title, venue, start_at, first_seen FROM events WHERE source=? AND gone=?",
    [slug, gone ? 1 : 0],
  )) {
    const title = String(r["title"] ?? "");
    const venue = String(r["venue"] ?? "");
    const k = `${norm(title)} ${venue}`;
    const b = out.get(k) ?? { title, venue, dates: [], firstSeen: "9999" };
    b.dates.push(String(r["start_at"]).slice(0, 10));
    const fs = String(r["first_seen"]);
    if (fs < b.firstSeen) b.firstSeen = fs;
    out.set(k, b);
  }
  return out;
}

/** Diff against the run BEFORE the latest one, so a fresh scrape does not read
 *  as "everything is new". */
function previousRun(conn: ReturnType<typeof db.connect>, slug: string): string | null {
  const r = db.one(
    conn,
    "SELECT started_at FROM runs WHERE slug=? AND ok=1 ORDER BY id DESC LIMIT 1 OFFSET 1",
    [slug],
  );
  return r ? String(r["started_at"]) : null;
}

export function main(o: RotateOpts): number {
  const conn = db.connect();
  const bl = db.blacklist();

  const todo = o.slugs.length
    ? o.slugs
    : db.all(conn, "SELECT slug FROM scrapers WHERE status='built' ORDER BY slug")
      .map((r) => String(r["slug"]))
      .filter((s) => !bl.sources.has(s));

  let shown = 0;
  for (const slug of todo) {
    const prev = previousRun(conn, slug);
    const live = blocks(conn, slug, false);
    const dead = blocks(conn, slug, true);

    const entered = [...live.values()]
      .filter((b) => b.dates.length >= o.minRun && prev && b.firstSeen > prev);
    const left = [...dead.entries()]
      .filter(([k, b]) => b.dates.length >= o.minRun && !live.has(k))
      .map(([, b]) => b);

    if (!entered.length && !left.length && !o.all) continue;
    shown++;

    const note = prev ? "" : "  (only one run on record - nothing to diff yet)";
    console.log(`== ${slug} ==${note}`);
    for (const b of entered) {
      const from = b.dates.slice().sort()[0] ?? "?";
      console.log(
        `   + ${b.title.slice(0, 46).padEnd(46)} ` +
        `${String(b.dates.length).padStart(2)} dates from ${from}`,
      );
    }
    for (const b of left) {
      console.log(
        `   - ${b.title.slice(0, 46).padEnd(46)} ` +
        `${String(b.dates.length).padStart(2)} dates dropped`,
      );
    }
    if (!entered.length && !left.length) console.log("   (no change)");
    console.log("");
  }

  if (!shown) console.log(`no rotation changes (run length >= ${o.minRun})`);
  return 0;
}
