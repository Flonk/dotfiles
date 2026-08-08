import assert from "node:assert/strict";
import { test } from "node:test";

import { num, parse, str, today } from "./args.ts";

test("boolean flags do not swallow the next argument", () => {
  // The regression: `--seed porgy` used to read porgy as the value of --seed,
  // so the slug silently vanished and only the other two sources ran.
  const f = parse(["--seed", "porgy", "mak", "nhm_events"]);
  assert.deepEqual(f.bare, ["porgy", "mak", "nhm_events"]);
  assert.equal(f.flags.get("seed"), true);
});

test("value flags take the next argument", () => {
  const f = parse(["--date", "2026-08-08", "--limit", "12", "--why"]);
  assert.equal(f.flags.get("date"), "2026-08-08");
  assert.equal(num(f, "limit", 40), 12);
  assert.equal(f.flags.get("why"), true);
  assert.deepEqual(f.bare, []);
});

test("--key=value form", () => {
  const f = parse(["--jobs=8", "--date=2026-01-01"]);
  assert.equal(num(f, "jobs", 4), 8);
  assert.equal(str(f, "date", "x"), "2026-01-01");
});

test("a value flag at the end of argv stays a boolean rather than eating undefined", () => {
  const f = parse(["--limit"]);
  assert.equal(f.flags.get("limit"), true);
  assert.equal(num(f, "limit", 40), 40);
});

test("a value flag followed by another flag does not consume it", () => {
  const f = parse(["--limit", "--why"]);
  assert.equal(num(f, "limit", 40), 40);
  assert.equal(f.flags.get("why"), true);
});

test("defaults survive junk", () => {
  const f = parse(["--jobs", "banana"]);
  assert.equal(num(f, "jobs", 4), 4);
});

test("today formats local time, not UTC", () => {
  assert.equal(today(new Date(2026, 0, 5, 23, 30)), "2026-01-05");
});
