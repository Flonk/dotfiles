import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";

import * as db from "./db.ts";
import type { EventRecord } from "./schema.ts";

const tmp = mkdtempSync(join(tmpdir(), "ea-test-"));
after(() => rmSync(tmp, { recursive: true, force: true }));

let n = 0;
function fresh() {
  return db.connect(join(tmp, `t${n++}.db`));
}

function rec(over: Partial<EventRecord> = {}): EventRecord {
  return {
    source: "porgy",
    source_id: "1",
    url: "https://www.porgy.at/events/1",
    title: "Trio",
    start: "2026-08-08T20:30",
    ...over,
  };
}

test("event id is composite - source+source_id alone is not unique", () => {
  // Cinemas reuse one screening-slot id across every date it runs.
  assert.equal(db.eventId(rec()), "porgy-1-2026-08-08T20:30");
  assert.notEqual(db.eventId(rec()), db.eventId(rec({ start: "2026-08-09T20:30" })));
});

test("pyDumps matches Python's json.dumps separators", () => {
  assert.equal(db.pyDumps(["a", null, 1]), '["a", null, 1]');
  assert.equal(db.pyDumps({ b: 1, a: 2 }, true), '{"a": 2, "b": 1}');
  assert.equal(db.pyDumps({ permanent: true }), '{"permanent": true}');
});

test("runtimeMin reads both numeric and prose durations", () => {
  assert.equal(db.runtimeMin({ duration_min: 95 }), 95);
  assert.equal(db.runtimeMin({ runtime: "95 min" }), 95);
  assert.equal(db.runtimeMin({ "Länge": "Länge: 128 Min." }), 128);
  assert.equal(db.runtimeMin({}), null);
  assert.equal(db.runtimeMin({ duration_text: "abends" }), null);
});

test("deriveEnd only ever extends a captured runtime, never guesses", () => {
  assert.equal(db.deriveEnd(rec({ extra: { duration_min: 90 } })), "2026-08-08T22:00");
  // no runtime -> no end. This is the invariant that stops fabricated end dates.
  assert.equal(db.deriveEnd(rec()), null);
  // date-only start has no time to add minutes to
  assert.equal(db.deriveEnd(rec({ start: "2026-08-08", extra: { duration_min: 90 } })), null);
  // an end the scraper actually published wins
  assert.equal(db.deriveEnd(rec({ end: "2026-08-08T23:00", extra: { duration_min: 90 } })), null);
  // implausible runtimes are refused rather than propagated
  assert.equal(db.deriveEnd(rec({ extra: { duration_min: 4000 } })), null);
  assert.equal(db.deriveEnd(rec({ extra: { duration_min: 0 } })), null);
});

test("deriveEnd rolls over midnight", () => {
  assert.equal(
    db.deriveEnd(rec({ start: "2026-08-08T23:30", extra: { duration_min: 90 } })),
    "2026-08-09T01:00",
  );
});

test("an end before its own start is dropped", () => {
  // A timed start with a date-only end on the same day reads as ending at
  // midnight, hours before it began. Seen on ait, klimtvilla, wko and others.
  assert.equal(db.usableEnd("2026-09-17T13:30", "2026-09-17"), null);
  assert.equal(db.usableEnd("2026-08-08T13:00", "2026-08-08"), null);
  // but a later date-only end is a real multi-day run
  assert.equal(db.usableEnd("2026-09-17T13:30", "2026-09-18"), "2026-09-18");
  assert.equal(db.usableEnd("2026-09-17", "2026-09-17"), "2026-09-17");
  assert.equal(db.usableEnd("2026-09-17T13:30", "2026-09-17T15:00"), "2026-09-17T15:00");
  assert.equal(db.usableEnd("2026-09-17", null), null);
});

test("a dropped end still lets a runtime-derived one through", () => {
  const row = db.toRow(rec({ end: "2026-08-08", extra: { duration_min: 90 } }));
  assert.equal(row["end_at"], "2026-08-08T22:00");
  assert.match(String(row["extra"]), /"end_derived": true/);
});

test("toRow marks a derived end so it is distinguishable from a published one", () => {
  const row = db.toRow(rec({ extra: { duration_min: 90 } }));
  assert.equal(row["end_at"], "2026-08-08T22:00");
  assert.match(String(row["extra"]), /"end_derived": true/);
  assert.equal(db.toRow(rec({ end: "2026-08-08T22:00" }))["extra"], null);
});

test("toRow carries image and defaults status", () => {
  const row = db.toRow(rec({ image: "https://x/still.jpg" }));
  assert.equal(row["image"], "https://x/still.jpg");
  assert.equal(row["status"], "scheduled");
});

test("hash changes only when a field changes", () => {
  const a = db.toRow(rec());
  assert.equal(a["hash"], db.toRow(rec())["hash"]);
  assert.notEqual(a["hash"], db.toRow(rec({ venue: "Porgy & Bess" }))["hash"]);
});

test("ingest counts new, changed and unchanged", () => {
  const conn = fresh();
  assert.deepEqual(db.ingest(conn, "porgy", [rec()]), { new: 1, changed: 0, gone: 0 });
  assert.deepEqual(db.ingest(conn, "porgy", [rec()]), { new: 0, changed: 0, gone: 0 });
  assert.deepEqual(
    db.ingest(conn, "porgy", [rec({ venue: "Porgy & Bess" })]),
    { new: 0, changed: 1, gone: 0 },
  );
});

test("a vanished record is soft-deleted, not dropped", () => {
  const conn = fresh();
  db.ingest(conn, "porgy", [rec({ source_id: "1" }), rec({ source_id: "2" })]);
  assert.deepEqual(
    db.ingest(conn, "porgy", [rec({ source_id: "1" })]),
    { new: 0, changed: 0, gone: 1 },
  );
  const row = db.one(conn, "SELECT gone FROM events WHERE source_id='2'");
  assert.equal(row?.["gone"], 1);
});

test("two ingests inside the same second still detect what vanished", () => {
  // The timestamp has second resolution, so a last_seen comparison silently
  // no-opped here. Gone-detection diffs by id instead.
  const conn = fresh();
  const stamp = db.now();
  db.ingest(conn, "porgy", [rec({ source_id: "1" }), rec({ source_id: "2" })], stamp);
  const r = db.ingest(conn, "porgy", [rec({ source_id: "1" })], stamp);
  assert.equal(r.gone, 1);
});

test("an empty harvest never marks a whole source gone", () => {
  const conn = fresh();
  db.ingest(conn, "porgy", [rec()]);
  assert.deepEqual(db.ingest(conn, "porgy", []), { new: 0, changed: 0, gone: 0 });
  assert.equal(db.one(conn, "SELECT gone FROM events")?.["gone"], 0);
});

test("a record that comes back is revived rather than duplicated", () => {
  const conn = fresh();
  db.ingest(conn, "porgy", [rec({ source_id: "1" }), rec({ source_id: "2" })]);
  db.ingest(conn, "porgy", [rec({ source_id: "1" })]);
  db.ingest(conn, "porgy", [rec({ source_id: "1" }), rec({ source_id: "2" })]);
  assert.equal(db.one(conn, "SELECT COUNT(*) AS n FROM events")?.["n"], 2);
  assert.equal(db.one(conn, "SELECT COUNT(*) AS n FROM events WHERE gone=1")?.["n"], 0);
});

test("one source going quiet does not touch another", () => {
  const conn = fresh();
  db.ingest(conn, "porgy", [rec()]);
  db.ingest(conn, "mak", [rec({ source: "mak" })]);
  db.ingest(conn, "mak", [rec({ source: "mak", source_id: "9" })]);
  assert.equal(
    db.one(conn, "SELECT gone FROM events WHERE source='porgy'")?.["gone"], 0,
  );
});

test("first_seen survives an update, so rotation detection stays honest", () => {
  const conn = fresh();
  db.ingest(conn, "porgy", [rec()], "2026-01-01T00:00:00");
  db.ingest(conn, "porgy", [rec({ venue: "Porgy" })], "2026-06-01T00:00:00");
  const row = db.one(conn, "SELECT first_seen, last_seen FROM events");
  assert.equal(row?.["first_seen"], "2026-01-01T00:00:00");
  assert.equal(row?.["last_seen"], "2026-06-01T00:00:00");
});

test("due respects cadence", () => {
  const conn = fresh();
  conn.exec(
    "INSERT INTO scrapers (slug, status, cadence, last_ok) VALUES" +
    " ('a','built','daily','2026-08-07T12:00:00')," +
    " ('b','built','weekly','2026-08-07T12:00:00')," +
    " ('c','built','daily',NULL)," +
    " ('d','dead','daily',NULL)",
  );
  assert.deepEqual(db.due(conn, new Date(2026, 7, 8, 13, 0)), ["a", "c"]);
  assert.deepEqual(db.due(conn, new Date(2026, 7, 8, 13, 0), true), ["a", "b", "c"]);
});

test("now has second resolution and no timezone suffix", () => {
  assert.equal(db.now(new Date(2026, 7, 8, 9, 5, 3)), "2026-08-08T09:05:03");
});
