# vienna_capitals

- URL: https://www.vienna-capitals.at/spielplan (Astro SSR, method=html)
- Full fixture list is server-rendered inline: `<article class="game-item-wrapper"
  data-start-at="..Z" data-game-type="1|7" data-home-away="home|away" data-month="...">`
  containing local `date`/`time` spans and two `team-name` spans (first = home, second
  = away). game-type 7 = pre-season friendlies/tournaments, 1 = regular ICE Hockey League.
- No per-game detail page/id exists, so `url` is the shared schedule URL for every record;
  `source_id` is synthesized as `date-home-slug-vs-away-slug`.
- `venue` is only present for neutral pre-season tournament games; regular season home/away
  games never list a venue on this page, left null rather than guessing the arena.
- `category` = the site's own "additional-information" text (tournament/theme night name)
  when present, else null — most regular-season games have none.
- Site publishes the full season, currently through late Feb 2027 (~6-7 months out), well
  past the 180-day horizon used here.
- Re-derive: curl the URL, grep for `game-item-wrapper`; if the markup class names change,
  update the regexes at the top of scrape.py.
