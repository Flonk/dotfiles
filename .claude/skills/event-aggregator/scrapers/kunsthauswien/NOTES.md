# kunsthauswien

- url: https://www.kunsthauswien.com/ (and its Craft CMS GraphQL API at /api/)
- method: api (GraphQL, POST, JSON body, no auth). Found by reading
  `assets/js/utilities/calendarHandler.js` linked from the /kalender page,
  which builds the queries used by the site's own JS calendar widget.
- Three combined sources: (1) `entries(section: ["exhibitions"], endDate: [">= today"])`
  for the 2 current temporary exhibitions (far end date each); (2) a
  hardcoded record for the permanent "Museum Hundertwasser" collection
  (no end date advertised anywhere -> extra.permanent); (3) `entries(type: "date", date: [...])`
  for ~40 dated occurrences (tours/talks/workshops/screenings), joined to
  their parent `section: ["events"]` entry by ownerId for title/url.
- Gotcha: date_Entry/event_Entry startTime/endTime fields store a bogus
  placeholder date (whatever day the field was saved) — only the HH:MM is
  meaningful; the real calendar day is date_Entry.date. Mirrors what the
  site's own JS does (`new Date(...).getHours()`).
- No price info anywhere in the API; price_min/price_text always null.
- Site publishes dated events only ~5 months out (through mid-Feb 2027
  currently, driven by one recurring "Öffentliche Touren" series).
- Re-derive: refetch /kalender, find `calendarHandler.js` script src, read
  its `queryDates`/`queryEvents` GraphQL strings — schema is introspectable
  at /api/ if fields change.
