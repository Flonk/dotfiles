# volume_at

- url: https://www.volume.at/events/, pagination via /events/<YYYY-MM-DD>/.
  Listing walk unchanged (forward date cursor, `abgesagt` cancel badge).
- New: fetches each item's own detail page (8-worker pool, wall-clock
  budgeted so bad network degrades fill instead of blowing check.py's
  300s kill) for start time (`<b>Beginn:</b> HH:MM Uhr` in `meta__time`,
  falls back to "Einlass"; ~12-15% publish neither, stay date-only),
  address+postal from `Event` JSON-LD `location.address` (falls back to
  the visible `<address>` block when empty), and `district` (1010-1230)
  from that postal. `end` always null - site never publishes one.
- Built while this sandbox's shared network was flaky (concurrent agent
  sessions -> bursts of "No route to host"); clean run ~1300 records,
  ~65%/70%/48% start-time/address/district fill - see meta.json notes.
- breaks if: `meta__time` markup or `Event` JSON-LD address shape changes.
