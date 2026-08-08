import * as db from "../db.ts";

const FILL = ["end_at", "venue", "district", "city", "price_min", "image", "description"];

export type StatsOpts = { top: number };

export function main(o: StatsOpts): number {
  const conn = db.connect();

  const live = Number(db.one(conn, "SELECT COUNT(*) AS n FROM events WHERE gone=0")?.["n"] ?? 0);
  const gone = Number(db.one(conn, "SELECT COUNT(*) AS n FROM events WHERE gone=1")?.["n"] ?? 0);
  const timed = Number(db.one(
    conn, "SELECT COUNT(*) AS n FROM events WHERE gone=0 AND instr(start_at,'T')>0",
  )?.["n"] ?? 0);

  console.log(`${live} live events (${gone} gone), ${timed} with a start time\n`);

  console.log("fill rates, live events");
  for (const f of FILL) {
    const n = Number(db.one(
      conn, `SELECT COUNT(*) AS n FROM events WHERE gone=0 AND ${f} IS NOT NULL`,
    )?.["n"] ?? 0);
    const pct = live ? Math.round((n * 100) / live) : 0;
    console.log(`  ${f.padEnd(12)} ${String(n).padStart(6)}  ${String(pct).padStart(3)}%`);
  }

  const byStatus = db.all(
    conn, "SELECT status, COUNT(*) AS n FROM scrapers GROUP BY status ORDER BY n DESC",
  );
  console.log(`\nscrapers: ${byStatus.map((r) => `${r["n"]} ${r["status"]}`).join(", ")}`);

  const failing = db.all(
    conn,
    "SELECT slug, fail_streak, last_error FROM scrapers WHERE fail_streak > 0" +
    " ORDER BY fail_streak DESC LIMIT 15",
  );
  if (failing.length) {
    console.log("\nfailing");
    for (const r of failing) {
      console.log(
        `  ${String(r["slug"]).padEnd(22)} ×${r["fail_streak"]}  ` +
        `${String(r["last_error"] ?? "").split("\n")[0]?.slice(0, 70)}`,
      );
    }
  }

  const never = db.all(
    conn, "SELECT slug FROM scrapers WHERE status='built' AND last_ok IS NULL ORDER BY slug",
  );
  if (never.length) {
    console.log(`\n${never.length} built but never ingested`);
  }

  console.log(`\ntop ${o.top} sources`);
  for (const r of db.all(
    conn,
    "SELECT source, COUNT(*) AS n FROM events WHERE gone=0" +
    " GROUP BY source ORDER BY n DESC LIMIT ?",
    [o.top],
  )) {
    console.log(`  ${String(r["source"]).padEnd(22)} ${String(r["n"]).padStart(6)}`);
  }
  return 0;
}
