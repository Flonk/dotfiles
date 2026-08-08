import assert from "node:assert/strict";
import { test } from "node:test";

import { parse } from "./scrape.ts";

const good = JSON.stringify({
  source: "porgy",
  source_id: "1",
  url: "https://www.porgy.at/events/1",
  title: "Trio",
  start: "2026-08-08T20:30",
});

test("one JSON record per line", () => {
  const h = parse(`${good}\n${good}\n`);
  assert.equal(h.valid.length, 2);
  assert.equal(h.invalid, 0);
});

test("blank lines are not records", () => {
  const h = parse(`\n${good}\n\n  \n`);
  assert.equal(h.valid.length, 1);
  assert.equal(h.invalid, 0);
});

test("a malformed line is counted, not fatal", () => {
  const h = parse(`${good}\nnot json\n${good}`);
  assert.equal(h.valid.length, 2);
  assert.equal(h.invalid, 1);
});

test("a schema-invalid record is rejected rather than stored", () => {
  const h = parse(`${good}\n${JSON.stringify({ source: "porgy" })}`);
  assert.equal(h.valid.length, 1);
  assert.equal(h.invalid, 1);
});
