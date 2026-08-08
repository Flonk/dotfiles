import assert from "node:assert/strict";
import { test } from "node:test";

import { encodeNonAscii } from "./url.ts";

test("plain ascii urls are untouched", () => {
  const u = "https://www.haydnkino.at/FilmImg/odyssey.jpg?a=1&b=2#x";
  assert.equal(encodeNonAscii(u), u);
});

test("non-ascii in the path is encoded", () => {
  assert.equal(
    encodeNonAscii("https://x.at/Bitteres-Fest_©-El-Deseo.jpg"),
    "https://x.at/Bitteres-Fest_%C2%A9-El-Deseo.jpg",
  );
  assert.equal(encodeNonAscii("https://x.at/Länge.jpg"), "https://x.at/L%C3%A4nge.jpg");
});

test("already-encoded urls are not double-encoded", () => {
  // encodeURI would turn %C2%A9 into %25C2%2525A9 here.
  const u = "https://x.at/a%20b_%C2%A9.jpg";
  assert.equal(encodeNonAscii(u), u);
});

test("idempotent", () => {
  const once = encodeNonAscii("https://x.at/Ö.jpg");
  assert.equal(encodeNonAscii(once), once);
});

test("astral characters survive as whole code points", () => {
  assert.equal(encodeNonAscii("https://x.at/a😀.jpg"), "https://x.at/a%F0%9F%98%80.jpg");
});

test("query strings and reserved characters are preserved", () => {
  const u = "https://schikaneder.at/img.jart?base=/prj3/waystone-db&img=x+y";
  assert.equal(encodeNonAscii(u), u);
});
