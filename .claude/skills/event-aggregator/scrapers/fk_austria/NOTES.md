# fk_austria

- url: https://www.fk-austria.at/teams/profis/spielplan
- method: html, server-rendered `.game-schedule-row` divs (Craft CMS, no JS needed)
- Publishes ~6 months ahead (currently through Feb 2027), well past the 180d horizon.
- Table mixes past results and future fixtures; future rows are those with goals `-`/`-`
  and filtered further to `start >= today`.
- Kickoff `01:00` is the site's TBD-time placeholder (verified: never a real ÖBL kickoff
  hour), so those rows emit date-only `start`.
- Home team is whichever club logo appears first of the two `team-logos` imgs; used to
  set `venue`/`district` (Generali-Arena, 1100) for home games only, null for away.
- `category` = alt text of the competition icon (ÖBL / ÖFB Cup / UECL) minus the
  "... white" icon-color suffix; the generic ball icon (pre-season friendlies) has no
  real competition label so category is null there.
- Re-derive: re-fetch the URL, re-check `game-schedule-row` markup and the goals `-`/`-`
  convention for unplayed matches.
