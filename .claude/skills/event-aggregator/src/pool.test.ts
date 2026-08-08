import assert from "node:assert/strict";
import { test } from "node:test";

import { pool } from "./pool.ts";

const tick = () => new Promise((r) => setTimeout(r, 1));

test("every item is processed exactly once", async () => {
  const items = Array.from({ length: 25 }, (_, i) => i);
  const seen: number[] = [];
  await pool(items, 4, async (i) => {
    await tick();
    return i * 2;
  }, (_, r) => seen.push(r as number));
  assert.deepEqual(seen.sort((a, b) => a - b), items.map((i) => i * 2));
});

test("concurrency is capped", async () => {
  let live = 0;
  let peak = 0;
  await pool(Array.from({ length: 20 }, (_, i) => i), 3, async () => {
    live++;
    peak = Math.max(peak, live);
    await tick();
    live--;
    return null;
  }, () => {});
  assert.equal(peak, 3);
});

test("a failing item is reported, not thrown, and the rest still run", async () => {
  // One dead scraper must not take the other 109 down with it.
  const ok: number[] = [];
  const errs: string[] = [];
  await pool([1, 2, 3], 2, async (i) => {
    if (i === 2) throw new Error("boom");
    return i;
  }, (_, r, e) => (e ? errs.push(e.message) : ok.push(r as number)));
  assert.deepEqual(ok.sort(), [1, 3]);
  assert.deepEqual(errs, ["boom"]);
});

test("a synchronous throw is caught too", async () => {
  const errs: string[] = [];
  await pool([1], 1, () => {
    throw new Error("sync boom");
  }, (_, __, e) => errs.push(e!.message));
  assert.deepEqual(errs, ["sync boom"]);
});

test("empty input is a no-op", async () => {
  let calls = 0;
  await pool([], 4, async () => calls++, () => {});
  assert.equal(calls, 0);
});
