import * as db from "../db.ts";
import { pool } from "../pool.ts";
import { fromSample, scrape, type Harvest } from "../scrape.ts";

export type ScrapeOpts = {
  slugs: string[];
  all: boolean;
  seed: boolean;
  dry: boolean;
  jobs: number;
};

export async function main(o: ScrapeOpts): Promise<number> {
  const conn = db.connect();
  db.syncMeta(conn);

  const todo = o.slugs.length
    ? o.slugs
    : db.due(conn, new Date(), o.all || o.seed);

  const horizons = new Map<string, number>();
  for (const r of db.all(conn, "SELECT slug, horizon_days FROM scrapers")) {
    horizons.set(String(r["slug"]), Number(r["horizon_days"]) || 180);
  }

  if (o.dry) {
    for (const s of todo) console.log(s);
    console.log(`${todo.length} due`);
    return 0;
  }
  if (!todo.length) {
    console.log("nothing due");
    return 0;
  }

  const open = conn.prepare("INSERT INTO runs (slug, started_at) VALUES (?, ?)");
  const closeOk = conn.prepare(
    "UPDATE runs SET finished_at=?, ok=1, n_valid=?, n_invalid=?," +
    " n_new=?, n_changed=?, n_gone=? WHERE id=?",
  );
  const closeErr = conn.prepare(
    "UPDATE runs SET finished_at=?, ok=0, error=? WHERE id=?",
  );
  const markOk = conn.prepare(
    "UPDATE scrapers SET last_run=?, last_ok=?, last_count=?," +
    " last_error=NULL, fail_streak=0 WHERE slug=?",
  );
  const markErr = conn.prepare(
    "UPDATE scrapers SET last_run=?, last_error=?," +
    " fail_streak=fail_streak+1 WHERE slug=?",
  );

  let ok = 0;
  let fail = 0;

  const work = async (slug: string): Promise<Harvest> => {
    const h = o.seed ? fromSample(slug) : await scrape(slug, horizons.get(slug) ?? 180);
    // Zero records is not the only way a redesign hurts. A parser that still
    // matches three items out of two hundred would ingest those three and mark
    // the rest gone - a silent amputation. The floor from meta.expect makes
    // that a recorded failure instead, leaving the existing records alone.
    const floor = db.readMeta(slug)?.expect?.min_records ?? 0;
    if (floor && h.valid.length < floor) {
      throw new Error(`only ${h.valid.length} valid records, expected >= ${floor}`);
    }
    return h;
  };

  await pool(todo, Math.max(1, o.jobs), work, (slug, res, err) => {
    const stamp = db.now();
    const runId = Number(open.run(slug, stamp).lastInsertRowid);
    if (err || !res) {
      const msg = (err?.message ?? "unknown error").slice(0, 500);
      closeErr.run(db.now(), msg, runId);
      markErr.run(stamp, msg, slug);
      fail++;
      console.log(`FAIL ${slug.padEnd(22)} ${(msg.split("\n")[0] ?? "").slice(0, 90)}`);
      return;
    }
    const n = db.ingest(conn, slug, res.valid, stamp);
    closeOk.run(db.now(), res.valid.length, res.invalid, n.new, n.changed, n.gone, runId);
    markOk.run(stamp, stamp, res.valid.length, slug);
    ok++;
    console.log(
      `ok   ${slug.padEnd(22)} ${String(res.valid.length).padStart(5)} rec` +
      `  +${n.new} ~${n.changed} -${n.gone}`,
    );
  });

  const live = db.one(conn, "SELECT COUNT(*) AS n FROM events WHERE gone=0");
  console.log(`\n${ok} ok, ${fail} failed | ${live?.["n"] ?? 0} live events`);
  return fail ? 1 : 0;
}
