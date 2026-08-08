# nhm_ausstellung

- url: https://www.nhm-wien.ac.at/ausstellung -> 301 -> www.nhm.at/ausstellung
  -> 302 -> www.nhm.at/ausstellung/sonderausstellungen (canonical, follow
  redirects). Method: html, server-rendered, no JS needed.
- One `div.ausstellung` per item inside `div.ausstellung-liste`, grouped under
  three `<h2>` sections: "Aktuelle Sonderausstellungen" (only an end date,
  "bis DD. Month YYYY" -> start set to scrape date, since the real opening
  date isn't published here), "Vorschau Sonderausstellungen" (either an
  explicit "DD. Month YYYY – DD. Month YYYY" range, or "ab DD. Month YYYY"
  which is treated as permanent/open-ended), and "Dauerausstellungsbereich"
  ("seit DD. Month YYYY" -> permanent, end null).
- Two of the items live in the Narrenturm (Spitalgasse 2, 1090 Wien) rather
  than the main building (Burgring 7, 1010); detected by "Narrenturm" text
  in the item's info line and given their own venue/district/address.
- No price info anywhere on list or detail pages -> price_min/price_text
  always null.
- Site shows the current lineup of ~9 special/new-permanent exhibitions with
  no real pagination; horizon is whatever's currently on display (seen out
  to mid-2027 for already-announced upcoming shows). Re-scrape periodically
  to pick up newly announced ones; no need to paginate.
- Re-derive: refetch the URL, canary string
  `ausstellung-liste ausstellung-liste--liste` marks the listing container.
