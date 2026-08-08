# WPI (Wolfgang Pauli Institute)

- URL: https://www.wpi.ac.at/activities_view.php?printall=2 (upcoming-only view;
  default `?s=event` page mixes in "Events of the past month")
- Method: html. Old-school 1990s-style server-rendered HTML, no JSON/ld+json anywhere.
- Each event is a `<table class=bordertable>` block: title+id via
  `event_view.php?id_activity=N` link, `Location:`, `Time: D. Mon YYYY (Day) - D. Mon
  YYYY (Day); Opening: HH:MM`, Organisation(s)/Organiser(s) lists, optional external
  website link and Topics list.
- Site only ever publishes a handful of events (2 at build time) a few months out —
  it's a workshop/conference calendar, not a recurring events feed. horizon_days=90
  is generous; the site itself rarely has anything beyond ~2 months ahead.
- No category or price fields exist on the site at all; both left null.
- Re-derive by re-fetching the printall=2 URL and checking the bordertable block
  structure and the `Time:` regex still match.
