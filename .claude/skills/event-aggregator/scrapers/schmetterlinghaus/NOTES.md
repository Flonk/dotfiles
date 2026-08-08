# schmetterlinghaus

- url: https://www.schmetterlinghaus.at/ (Duda site builder, server-rendered
  HTML, no JS needed). Method: html.
- No events/exhibitions calendar exists on the site at all - the nav item
  "News & Events" (/newpage432d3685) just links to Facebook/Instagram/
  YouTube, nothing dated. This is a single permanent tropical butterfly
  house, open year-round.
- scrape.py fetches the homepage (canary "Schmetterlinghaus", used as a
  liveness check) plus /preise, and emits exactly one record: the
  attraction itself, start = scrape date (real opening date not published
  anywhere), end null, extra.permanent = true. Per the no-fabrication rule,
  never invent a future end date for this.
- price_min/price_text come from the "Erwachsene" (adult) row of the
  /preise pricing table (`<td class="cell">Erwachsene</td><td...10,00</td>
  <td...9,00</td>`) - single-entry vs. group price. No other price info
  exists.
- venue/address/district (1010, Palmenhaus Burggarten, Hofburg) come from
  /kontakt, hardcoded (static, unlikely to change).
- Breaks if: the /preise table markup changes (`class="cell"` td structure)
  or the "Erwachsene" row label changes. Re-derive by refetching /preise
  and diffing the table HTML.
