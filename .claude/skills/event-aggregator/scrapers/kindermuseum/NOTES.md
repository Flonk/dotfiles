# kindermuseum

- url: https://www.kindermuseum.at/ (JART CMS, old FreeBSD/Apache stack)
- method: html, fixed list of "programm" hub pages in `scrape.py:PAGES`. No sitewide
  events calendar exists; each page just shows the currently-running offering for that
  section (Ausstellung / Atelier / Ozean / Trickfilmstudio / Fragwuerdig-Kindervorlesungen).
- Each page has exactly one `<article class="db-article-display" ...>...</article>` block.
  Title from `<h2 class="title">`, id from `article_id_<digits>` in the class list.
- Most pages have no explicit dates -> emitted as one permanent record
  (`extra.permanent=true`, `start`=today, `end`=null). A minority carry a structured
  `Laufzeit: <d> - <d>` range (emit as one dated record, skipped if already past - the
  site is often stale between seasons) or a `TERMINE` block listing single dated slots
  like "28. Oktober 10.00 Uhr" (emit one record per slot; year inferred from a 4-digit
  year elsewhere in the article text).
- Site publishes only what's currently on: no real forward horizon beyond whatever
  the next-announced workshop dates happen to be (here: Oct 2026). `EA_HORIZON_DAYS`
  mostly irrelevant since there's nothing to paginate.
- The server is badly flaky: needs a JSESSIONID cookie from an initial redirect, and
  a large fraction of requests just hang for 1-2+ minutes with no data. `scrape.py`
  builds its own `urllib` opener with a `CookieJar` and fetches with a 20s timeout and
  2 retries per page; a page that never answers is skipped for that run (yield varies,
  5-6 of 6 pages typically succeed).
- Price: first `€`/`EUR` amount in the article text, else `0` if "Eintritt frei" is
  present, else null.
