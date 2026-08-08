/**
 * Percent-encode the non-ASCII code points in a URL and nothing else.
 *
 * 59 of our 872 image URLs arrive with raw UTF-8 in the path, e.g.
 * `.../Bitteres-Fest_Still-01_©-El-Deseo.jpg`. Browsers and node's fetch both
 * cope with that - measured, not assumed - so this is hygiene rather than a
 * fix for a live breakage: Python's urllib raises UnicodeEncodeError on it,
 * `format: uri` wants it encoded, and it keeps the stored value canonical.
 *
 * `encodeURI` is the wrong tool because it also escapes `%`, double-encoding
 * anything already correct. Touching only the non-ASCII leaves valid URLs
 * byte-identical and makes the function idempotent.
 */
export function encodeNonAscii(u: string): string {
  // eslint-disable-next-line no-control-regex
  if (!/[^\x00-\x7F]/u.test(u)) return u;
  return u.replace(/[^\x00-\x7F]/gu, (c) => {
    try {
      return encodeURIComponent(c);
    } catch {
      return c;
    }
  });
}
