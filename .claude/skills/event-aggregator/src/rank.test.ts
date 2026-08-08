import assert from "node:assert/strict";
import { test } from "node:test";

import type { Row } from "./db.ts";
import { norm, parts, score } from "./rank.ts";

const TODAY = "2026-08-08";

function row(over: Partial<Row> = {}): Row {
  return {
    title: "Thing",
    venue: "Venue",
    start_at: "2026-08-08T20:00",
    end_at: null,
    price_min: null,
    extra: null,
    ...over,
  };
}

test("norm strips screening-format noise so one film is one run", () => {
  assert.equal(norm("Sinners (OmeU)"), norm("Sinners"));
  assert.equal(norm("Sinners -2D- OmU"), norm("Sinners"));
  // Umlauts are dropped rather than folded - fine for grouping a run, but it
  // means "Über" and "ber" collide. Don't reuse norm() for display.
  assert.equal(norm("Die Ärzte!"), "dierzte");
});

test("permanent collections count as maximally unspecific", () => {
  // end_at IS NULL used to read as span 1, scoring a permanent collection as a
  // maximally specific one-off - exactly backwards.
  const p = parts(row({ end_at: null, extra: '{"permanent": true}' }), TODAY);
  assert.equal(p.permanent, true);
  assert.ok(p.span > 9000);
});

test("a one-off outranks a long run, which outranks a permanent", () => {
  const oneOff = score(row(), 1, TODAY).score;
  const longRun = score(row({ end_at: "2026-12-31" }), 12, TODAY).score;
  const permanent = score(row({ extra: '{"permanent": true}' }), 40, TODAY).score;
  assert.ok(oneOff > longRun, `${oneOff} > ${longRun}`);
  assert.ok(longRun > permanent, `${longRun} > ${permanent}`);
});

test("both demotion axes fire independently", () => {
  assert.ok(score(row(), 8, TODAY).why.includes("run×8"));
  assert.ok(!score(row(), 7, TODAY).why.some((w) => w.startsWith("run×")));
  assert.ok(score(row({ end_at: "2026-12-01" }), 1, TODAY).why.some((w) => w.startsWith("runs ")));
});

test("last chance repeals the span demotion", () => {
  // A long exhibition three weeks from closing is news again.
  const early = score(row({ start_at: "2026-08-08", end_at: "2027-02-01" }), 1, TODAY);
  const closing = score(row({ start_at: "2026-02-01", end_at: "2026-08-20" }), 1, TODAY);
  assert.ok(closing.score > early.score, `${closing.score} > ${early.score}`);
  assert.ok(closing.why.some((w) => w.startsWith("LAST CHANCE")));
});

test("last chance does not fire on something already over", () => {
  const s = score(row({ start_at: "2026-01-01", end_at: "2026-07-01" }), 1, TODAY);
  assert.ok(!s.why.some((w) => w.startsWith("LAST CHANCE")));
});

test("last chance does not fire on a short run", () => {
  const s = score(row({ start_at: "2026-08-08", end_at: "2026-08-09" }), 1, TODAY);
  assert.ok(!s.why.some((w) => w.startsWith("LAST CHANCE")));
});

test("permanents never get a last chance", () => {
  const s = score(row({ end_at: null, extra: '{"permanent": true}' }), 1, TODAY);
  assert.ok(!s.why.some((w) => w.startsWith("LAST CHANCE")));
});

test("free is a nudge, not a lever", () => {
  const paid = score(row({ price_min: 25 }), 1, TODAY).score;
  const free = score(row({ price_min: 0 }), 1, TODAY).score;
  assert.equal(free - paid, 5);
});

test("a single-date event is scored as a one-off", () => {
  assert.ok(score(row(), 1, TODAY).why.includes("one-off"));
  assert.ok(!score(row(), 3, TODAY).why.includes("one-off"));
});
