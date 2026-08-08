# univie_physik

- url: https://physik.univie.ac.at/events/
- method: html. TYPO3 news-list of type "Events" (`news-box article`
  divs). No pagination seen at build time (only 2 items). The date chip
  in the `.news-category-name` div is the article's *publish* date, not
  the event date -- do not use it. The real start/end/venue/category are
  free-text inside the `itemprop="description"` teaser, in one of two
  observed shapes:
  - single day: `<Weekday>, DD.MM.YYYY, HH:MM` / venue line / optional
    `Event from <category>` line
  - range: `<Weekday>, DD - <Weekday>, DD Month YYYY` / `Ort: <venue>`
    (no category line)
- scrape.py regexes both shapes; category stays null when no
  "Event from ..." line is present (true for external-org events).
- Separately, /events/colloquium/ is the weekly Physics Colloquium but is
  entirely semester-bound HTML (date/speaker/title blocks with no ids),
  and at build time only shows the finished SS26 run (through 15 June
  2026) -- WS26/27 not yet posted, so it's skipped; not worth building a
  parser for a page with 0 current yield. Re-check in Sept/Oct.
- Publishes only a couple of months out (through late Sep from an
  early-Aug run) because it's just whatever faculty events happen to be
  announced, not a recurring feed.
