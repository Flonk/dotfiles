# ISTA

url (meta): https://ista.ac.at/en/news-events/events/ — but this page only server-renders
a 6-item teaser slider (`m03` slider). The real listing lives on a separate Rails app,
`talks-calendar.ista.ac.at`, linked from event tiles (`/events/<eid>`).

method: api (two calls to talks-calendar.ista.ac.at, no auth)
- `GET /events` — HTML table (`#event_table`) with all upcoming events; used only for the
  "Series" column (category), since the ICS has no category.
- `GET /generate_all_ics` — one ICS feed with every upcoming event's start/end/location/
  description/url. DTSTART/DTEND have no TZID/Z suffix — they're floating Europe/Vienna
  local time already, matching the schema's date format directly.
Joined by event id parsed out of the `/events/<id>` URL in both.

Horizon: the site itself only ever lists ~20 upcoming talks, currently spanning today
(2026-08-08) out to mid-Jan 2027 (~5 months), so there's nothing to paginate — one fetch
gets everything the site publishes. `EA_HORIZON_DAYS` still trims records past the cutoff.

No pricing info anywhere (academic talks) — price_min/price_text always null, never guessed.

Location strings are ISTA campus building/room names (Klosterneuburg, Lower Austria), not
Vienna — district/city only get set on the rare event held at an address with a 10xx
Vienna postal code (e.g. ÖAW building on Dr. Ignaz Seipel-Platz).

Re-derive: if `/events` table markup or `/generate_all_ics` shape changes, re-inspect both
by curling talks-calendar.ista.ac.at directly.
