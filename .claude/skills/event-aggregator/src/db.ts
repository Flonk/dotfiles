import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";

import { BLACKLIST_PATH, DB_PATH, SCRAPERS } from "./paths.ts";
import type { EventRecord } from "./schema.ts";

export const FIELDS = [
  "url", "title", "start_at", "end_at", "venue", "district", "city",
  "address", "price_min", "price_text", "category", "description",
  "image", "status", "extra",
] as const;

export const INTERVAL_DAYS: Record<string, number> = {
  daily: 1,
  weekly: 7,
  monthly: 30,
};

const RUNTIME_KEYS = [
  "duration_min", "duration_text", "Länge", "runtime", "origin_year_runtime",
];

const SCHEMA = `
CREATE TABLE IF NOT EXISTS events (
  id          TEXT PRIMARY KEY,
  source      TEXT NOT NULL,
  source_id   TEXT NOT NULL,
  url         TEXT,
  title       TEXT NOT NULL,
  start_at    TEXT NOT NULL,
  end_at      TEXT,
  venue       TEXT,
  district    INTEGER,
  city        TEXT,
  address     TEXT,
  price_min   REAL,
  price_text  TEXT,
  category    TEXT,
  description TEXT,
  image       TEXT,
  status      TEXT DEFAULT 'scheduled',
  extra       TEXT,
  hash        TEXT NOT NULL,
  first_seen  TEXT NOT NULL,
  last_seen   TEXT NOT NULL,
  gone        INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_events_start  ON events(start_at);
CREATE INDEX IF NOT EXISTS ix_events_source ON events(source, gone);
CREATE INDEX IF NOT EXISTS ix_events_live   ON events(gone, start_at);

CREATE TABLE IF NOT EXISTS scrapers (
  slug         TEXT PRIMARY KEY,
  status       TEXT,
  method       TEXT,
  grp          TEXT,
  cadence      TEXT,
  horizon_days INTEGER,
  last_run     TEXT,
  last_ok      TEXT,
  last_error   TEXT,
  last_count   INTEGER,
  fail_streak  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS runs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  slug        TEXT NOT NULL,
  started_at  TEXT NOT NULL,
  finished_at TEXT,
  ok          INTEGER,
  n_valid     INTEGER,
  n_invalid   INTEGER,
  n_new       INTEGER,
  n_changed   INTEGER,
  n_gone      INTEGER,
  error       TEXT
);
CREATE INDEX IF NOT EXISTS ix_runs_slug ON runs(slug, started_at);
`;

export type Row = Record<string, string | number | null>;

export function connect(path?: string): DatabaseSync {
  const conn = new DatabaseSync(path || DB_PATH);
  conn.exec("PRAGMA journal_mode=WAL");
  conn.exec("PRAGMA foreign_keys=ON");
  conn.exec(SCHEMA);
  const have = new Set(
    (conn.prepare("PRAGMA table_info(events)").all() as Row[])
      .map((r) => String(r["name"])),
  );
  for (const [col, decl] of [["image", "TEXT"]] as const) {
    if (!have.has(col)) conn.exec(`ALTER TABLE events ADD COLUMN ${col} ${decl}`);
  }
  return conn;
}

export function all(conn: DatabaseSync, sql: string, params: unknown[] = []): Row[] {
  return conn.prepare(sql).all(...(params as never[])) as Row[];
}

export function one(conn: DatabaseSync, sql: string, params: unknown[] = []): Row | undefined {
  return conn.prepare(sql).get(...(params as never[])) as Row | undefined;
}

/** Local timestamp, second resolution — matches the Python `db.now()` format. */
export function now(at: Date = new Date()): string {
  const p = (n: number) => String(n).padStart(2, "0");
  return `${at.getFullYear()}-${p(at.getMonth() + 1)}-${p(at.getDate())}` +
    `T${p(at.getHours())}:${p(at.getMinutes())}:${p(at.getSeconds())}`;
}

/**
 * json.dumps-compatible serialiser: Python's default separators are ", " and
 * ": ", JSON.stringify uses "," and ":". Matching them keeps stored `extra`
 * blobs byte-identical across the Python and TypeScript pipelines during the
 * migration, so a switch-over does not rewrite every row.
 */
export function pyDumps(v: unknown, sortKeys = false): string {
  if (v === null || v === undefined) return "null";
  if (typeof v === "string") return JSON.stringify(v);
  if (typeof v === "boolean") return v ? "true" : "false";
  if (typeof v === "number") return String(v);
  if (Array.isArray(v)) {
    return "[" + v.map((x) => pyDumps(x, sortKeys)).join(", ") + "]";
  }
  if (typeof v === "object") {
    const obj = v as Record<string, unknown>;
    const keys = Object.keys(obj);
    if (sortKeys) keys.sort();
    return "{" + keys
      .map((k) => `${JSON.stringify(k)}: ${pyDumps(obj[k], sortKeys)}`)
      .join(", ") + "}";
  }
  return "null";
}

/**
 * Python prints a float 15.0 as "15.0" where JS prints "15", and price_min is
 * the one genuinely-float column feeding the change hash. Without this the
 * first TypeScript run would report every priced event as changed: 5410 of the
 * 11.3k records carry a float price, against 13 that carry an int literal.
 */
function pyFloat(v: number): string {
  return Number.isInteger(v) ? `${v}.0` : String(v);
}

const FLOAT_FIELDS = new Set<string>(["price_min"]);

export type Blacklist = {
  sources: Set<string>;
  venues: string[];
  titles: string[];
};

export function blacklist(): Blacklist {
  if (!existsSync(BLACKLIST_PATH)) {
    return { sources: new Set(), venues: [], titles: [] };
  }
  const b = JSON.parse(readFileSync(BLACKLIST_PATH, "utf8")) as {
    sources?: { slug: string }[];
    venues?: string[];
    titles?: string[];
  };
  return {
    sources: new Set((b.sources || []).map((s) => s.slug)),
    venues: (b.venues || []).map((v) => v.toLowerCase()),
    titles: (b.titles || []).map((t) => t.toLowerCase()),
  };
}

export function isBlacklisted(row: Row, bl: Blacklist): boolean {
  if (bl.sources.has(String(row["source"]))) return true;
  const v = String(row["venue"] ?? "").toLowerCase();
  const t = String(row["title"] ?? "").toLowerCase();
  return bl.venues.some((x) => v.includes(x)) || bl.titles.some((x) => t.includes(x));
}

export function runtimeMin(extra: Record<string, unknown>): number | null {
  for (const k of RUNTIME_KEYS) {
    const v = extra[k];
    if (v === null || v === undefined) continue;
    if (typeof v === "number") return Math.trunc(v);
    const m = /(\d{2,3})\s*min/i.exec(String(v));
    if (m) return Number(m[1]);
  }
  return null;
}

/** Only ever derives from a runtime the scraper actually captured. Never guesses. */
export function deriveEnd(rec: EventRecord): string | null {
  if (rec.end || !(rec.start || "").includes("T")) return null;
  const mins = runtimeMin(rec.extra || {});
  if (!mins || mins < 1 || mins > 600) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(rec.start);
  if (!m) return null;
  const d = new Date(
    Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]),
  );
  d.setMinutes(d.getMinutes() + mins);
  return now(d).slice(0, 16);
}

export function eventId(rec: EventRecord): string {
  return `${rec.source}-${rec.source_id}-${rec.start}`;
}

export function toRow(rec: EventRecord): Row {
  const extra: Record<string, unknown> = { ...(rec.extra || {}) };
  const end = rec.end || deriveEnd(rec);
  if (end && !rec.end) extra["end_derived"] = true;

  const row: Row = {
    id: eventId(rec),
    source: rec.source,
    source_id: String(rec.source_id),
    url: rec.url ?? null,
    title: rec.title,
    start_at: rec.start,
    end_at: end ?? null,
    venue: rec.venue ?? null,
    district: rec.district ?? null,
    city: rec.city ?? null,
    address: rec.address ?? null,
    price_min: rec.price_min ?? null,
    price_text: rec.price_text ?? null,
    category: rec.category ?? null,
    description: rec.description ?? null,
    image: rec.image ?? null,
    status: rec.status || "scheduled",
    extra: Object.keys(extra).length ? pyDumps(extra, true) : null,
  };
  const payload = "[" + FIELDS.map((f) => {
    const v = row[f];
    return FLOAT_FIELDS.has(f) && typeof v === "number" ? pyFloat(v) : pyDumps(v);
  }).join(", ") + "]";
  row["hash"] = createHash("sha1").update(payload, "utf8").digest("hex").slice(0, 16);
  return row;
}

export type IngestResult = { new: number; changed: number; gone: number };

export function ingest(
  conn: DatabaseSync,
  slug: string,
  recs: EventRecord[],
  stamp?: string,
): IngestResult {
  const at = stamp || now();
  const rows = new Map<string, Row>();
  for (const r of recs) {
    const row = toRow(r);
    rows.set(String(row["id"]), row);
  }

  const have = new Map<string, string>();
  for (const r of all(conn, "SELECT id, hash FROM events WHERE source=?", [slug])) {
    have.set(String(r["id"]), String(r["hash"]));
  }

  const cols = FIELDS.join(", ");
  const marks = new Array(3 + FIELDS.length).fill("?").join(", ");
  const insert = conn.prepare(
    `INSERT INTO events (id, source, source_id, ${cols}, hash, first_seen,` +
    ` last_seen, gone) VALUES (${marks}, ?, ?, ?, 0)`,
  );
  const update = conn.prepare(
    `UPDATE events SET ${FIELDS.map((f) => `${f}=?`).join(", ")},` +
    " hash=?, last_seen=?, gone=0 WHERE id=?",
  );
  const touch = conn.prepare("UPDATE events SET last_seen=?, gone=0 WHERE id=?");

  let created = 0;
  let changed = 0;
  for (const [rid, row] of rows) {
    const prev = have.get(rid);
    if (prev === undefined) {
      created++;
      insert.run(
        ...([row["id"], row["source"], row["source_id"],
          ...FIELDS.map((f) => row[f]), row["hash"], at, at] as never[]),
      );
    } else if (prev !== row["hash"]) {
      changed++;
      update.run(
        ...([...FIELDS.map((f) => row[f]), row["hash"], at, rid] as never[]),
      );
    } else {
      touch.run(at, rid);
    }
  }

  // Diff by identity, not by timestamp: two ingests of one source inside the
  // same second would make a last_seen comparison silently no-op.
  let gone = 0;
  if (rows.size) {
    conn.exec("CREATE TEMP TABLE IF NOT EXISTS _seen (id TEXT PRIMARY KEY)");
    conn.exec("DELETE FROM _seen");
    const ins = conn.prepare("INSERT OR IGNORE INTO _seen VALUES (?)");
    for (const k of rows.keys()) ins.run(k);
    const res = conn.prepare(
      "UPDATE events SET gone=1 WHERE source=? AND gone=0" +
      " AND id NOT IN (SELECT id FROM _seen)",
    ).run(slug);
    gone = Number(res.changes);
    conn.exec("DELETE FROM _seen");
  }
  return { new: created, changed, gone };
}

export type ScraperMeta = {
  slug: string;
  status?: string;
  method?: string;
  group?: string;
  schedule?: { cadence?: string; horizon_days?: number };
  expect?: { min_records?: number; required_fill?: Record<string, number>; canary?: string };
};

export function readMeta(slug: string): ScraperMeta | null {
  const p = join(SCRAPERS, slug, "meta.json");
  if (!existsSync(p)) return null;
  return JSON.parse(readFileSync(p, "utf8")) as ScraperMeta;
}

export function syncMeta(conn: DatabaseSync): number {
  const stmt = conn.prepare(
    "INSERT INTO scrapers (slug, status, method, grp, cadence, horizon_days)" +
    " VALUES (?, ?, ?, ?, ?, ?)" +
    " ON CONFLICT(slug) DO UPDATE SET status=excluded.status," +
    " method=excluded.method, grp=excluded.grp, cadence=excluded.cadence," +
    " horizon_days=excluded.horizon_days",
  );
  let n = 0;
  for (const slug of readdirSync(SCRAPERS).sort()) {
    const m = readMeta(slug);
    if (!m) continue;
    const s = m.schedule || {};
    stmt.run(
      slug, m.status ?? null, m.method ?? null, m.group ?? null,
      s.cadence || "weekly", s.horizon_days || 180,
    );
    n++;
  }
  return n;
}

export function due(conn: DatabaseSync, at: Date = new Date(), force = false): string[] {
  const out: string[] = [];
  for (const r of all(conn, "SELECT * FROM scrapers WHERE status='built' ORDER BY slug")) {
    const slug = String(r["slug"]);
    if (force || !r["last_ok"]) {
      out.push(slug);
      continue;
    }
    const last = new Date(String(r["last_ok"]));
    if (Number.isNaN(last.getTime())) {
      out.push(slug);
      continue;
    }
    const days = INTERVAL_DAYS[String(r["cadence"])] ?? 7;
    if (at.getTime() - last.getTime() >= days * 86_400_000) out.push(slug);
  }
  return out;
}
