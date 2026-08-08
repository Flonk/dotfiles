import assert from "node:assert/strict";
import { test } from "node:test";

import { validate } from "./schema.ts";

const good = {
  source: "porgy",
  source_id: "1234",
  url: "https://www.porgy.at/events/1234",
  title: "Diknu Schneeberger Trio",
  start: "2026-08-08T20:30",
};

test("a minimal record validates", () => {
  assert.deepEqual(validate(good), []);
});

test("every required field is enforced", () => {
  for (const k of ["source", "source_id", "url", "title", "start"]) {
    const r: Record<string, unknown> = { ...good };
    delete r[k];
    assert.deepEqual(validate(r), [`missing required ${k}`], k);
  }
});

test("empty string counts as missing", () => {
  assert.deepEqual(validate({ ...good, title: "" }), ["missing required title"]);
});

test("unknown fields are rejected so typos cannot silently vanish", () => {
  assert.deepEqual(validate({ ...good, img: "https://x/y.jpg" }), ["unknown field img"]);
});

test("date shapes", () => {
  assert.deepEqual(validate({ ...good, start: "2026-08-08" }), []);
  assert.deepEqual(validate({ ...good, end: "2026-08-08T22:00" }), []);
  assert.equal(validate({ ...good, start: "08.08.2026" }).length, 1);
  assert.equal(validate({ ...good, start: "2026-08-08T20:30:00" }).length, 1);
});

test("nullable versus non-nullable", () => {
  assert.deepEqual(validate({ ...good, venue: null }), []);
  assert.deepEqual(validate({ ...good, title: null }), [
    "missing required title",
    "title must not be null",
  ]);
});

test("status is an enum", () => {
  assert.deepEqual(validate({ ...good, status: "cancelled" }), []);
  assert.equal(validate({ ...good, status: "abgesagt" }).length, 1);
});

test("district is bounded to Vienna postal codes", () => {
  assert.deepEqual(validate({ ...good, district: 1070 }), []);
  assert.deepEqual(validate({ ...good, district: 8010 }), ["district above maximum"]);
  assert.deepEqual(validate({ ...good, district: 1000 }), ["district below minimum"]);
});

test("price_min may not be negative", () => {
  assert.deepEqual(validate({ ...good, price_min: 0 }), []);
  assert.deepEqual(validate({ ...good, price_min: -5 }), ["price_min below minimum"]);
});

test("wrong types are caught", () => {
  assert.equal(validate({ ...good, district: "1070" }).length, 1);
  assert.equal(validate({ ...good, extra: "permanent" }).length, 1);
  assert.deepEqual(validate({ ...good, extra: { permanent: true } }), []);
});

test("non-objects", () => {
  assert.deepEqual(validate(null), ["not an object"]);
  assert.deepEqual(validate([good]), ["not an object"]);
});
