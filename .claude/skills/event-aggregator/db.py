import datetime as dt
import hashlib
import json
import os
import re
import sqlite3

ROOT = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.environ.get("EA_DB") or os.path.join(ROOT, "events.db")

FIELDS = ["url", "title", "start_at", "end_at", "venue", "district", "city",
          "address", "price_min", "price_text", "category", "description",
          "status", "extra"]

INTERVAL_DAYS = {"daily": 1, "weekly": 7, "monthly": 30}

RUNTIME_KEYS = ("duration_min", "duration_text", "Länge", "runtime",
                "origin_year_runtime")

SCHEMA = """
CREATE TABLE IF NOT EXISTS events (
  id          TEXT PRIMARY KEY,
  source      TEXT NOT NULL,
  source_id   TEXT NOT NULL,
  url         TEXT,
  title       TEXT NOT NULL,
  start_at    TEXT NOT NULL,
  end_at      TEXT,
  venue       TEXT,
  district    INTEGER,
  city        TEXT,
  address     TEXT,
  price_min   REAL,
  price_text  TEXT,
  category    TEXT,
  description TEXT,
  status      TEXT DEFAULT 'scheduled',
  extra       TEXT,
  hash        TEXT NOT NULL,
  first_seen  TEXT NOT NULL,
  last_seen   TEXT NOT NULL,
  gone        INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS ix_events_start  ON events(start_at);
CREATE INDEX IF NOT EXISTS ix_events_source ON events(source, gone);
CREATE INDEX IF NOT EXISTS ix_events_live   ON events(gone, start_at);

CREATE TABLE IF NOT EXISTS scrapers (
  slug         TEXT PRIMARY KEY,
  status       TEXT,
  method       TEXT,
  grp          TEXT,
  cadence      TEXT,
  horizon_days INTEGER,
  last_run     TEXT,
  last_ok      TEXT,
  last_error   TEXT,
  last_count   INTEGER,
  fail_streak  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS runs (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  slug        TEXT NOT NULL,
  started_at  TEXT NOT NULL,
  finished_at TEXT,
  ok          INTEGER,
  n_valid     INTEGER,
  n_invalid   INTEGER,
  n_new       INTEGER,
  n_changed   INTEGER,
  n_gone      INTEGER,
  error       TEXT
);
CREATE INDEX IF NOT EXISTS ix_runs_slug ON runs(slug, started_at);
"""


def blacklist():
    p = os.path.join(ROOT, "blacklist.json")
    if not os.path.exists(p):
        return set(), [], []
    b = json.load(open(p, encoding="utf-8"))
    return ({s["slug"] for s in b.get("sources") or []},
            [v.lower() for v in b.get("venues") or []],
            [t.lower() for t in b.get("titles") or []])


def blacklisted(rec):
    srcs, venues, titles = blacklist()
    if rec.get("source") in srcs:
        return True
    v = (rec.get("venue") or "").lower()
    t = (rec.get("title") or "").lower()
    return any(x in v for x in venues) or any(x in t for x in titles)


def connect(path=None):
    conn = sqlite3.connect(path or DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.executescript(SCHEMA)
    return conn


def now():
    return dt.datetime.now().replace(microsecond=0).isoformat()


def runtime_min(extra):
    for k in RUNTIME_KEYS:
        v = extra.get(k)
        if v is None:
            continue
        if isinstance(v, (int, float)):
            return int(v)
        m = re.search(r"(\d{2,3})\s*min", str(v), re.I)
        if m:
            return int(m.group(1))
    return None


def derive_end(rec):
    if rec.get("end") or "T" not in (rec.get("start") or ""):
        return None
    mins = runtime_min(rec.get("extra") or {})
    if not mins or not 1 <= mins <= 600:
        return None
    try:
        s = dt.datetime.strptime(rec["start"], "%Y-%m-%dT%H:%M")
    except ValueError:
        return None
    return (s + dt.timedelta(minutes=mins)).strftime("%Y-%m-%dT%H:%M")


def event_id(rec):
    return "%s-%s-%s" % (rec["source"], rec["source_id"], rec["start"])


def to_row(rec):
    e = dict(rec.get("extra") or {})
    end = rec.get("end") or derive_end(rec)
    if end and not rec.get("end"):
        e["end_derived"] = True
    row = {
        "id": event_id(rec),
        "source": rec["source"],
        "source_id": str(rec["source_id"]),
        "url": rec.get("url"),
        "title": rec["title"],
        "start_at": rec["start"],
        "end_at": end,
        "venue": rec.get("venue"),
        "district": rec.get("district"),
        "city": rec.get("city"),
        "address": rec.get("address"),
        "price_min": rec.get("price_min"),
        "price_text": rec.get("price_text"),
        "category": rec.get("category"),
        "description": rec.get("description"),
        "status": rec.get("status") or "scheduled",
        "extra": json.dumps(e, ensure_ascii=False, sort_keys=True) if e else None,
    }
    payload = json.dumps([row[f] for f in FIELDS], ensure_ascii=False)
    row["hash"] = hashlib.sha1(payload.encode()).hexdigest()[:16]
    return row


def ingest(conn, slug, recs, stamp=None):
    stamp = stamp or now()
    rows = {}
    for r in recs:
        row = to_row(r)
        rows[row["id"]] = row
    have = {r["id"]: r["hash"] for r in
            conn.execute("SELECT id, hash FROM events WHERE source=?", (slug,))}
    new = changed = 0
    for rid, row in rows.items():
        if rid not in have:
            new += 1
            conn.execute(
                "INSERT INTO events (id, source, source_id, %s, hash, first_seen,"
                " last_seen, gone) VALUES (%s, ?, ?, ?, 0)"
                % (", ".join(FIELDS), ", ".join("?" * (3 + len(FIELDS)))),
                [row["id"], row["source"], row["source_id"]]
                + [row[f] for f in FIELDS] + [row["hash"], stamp, stamp])
        elif have[rid] != row["hash"]:
            changed += 1
            conn.execute(
                "UPDATE events SET %s, hash=?, last_seen=?, gone=0 WHERE id=?"
                % ", ".join(f + "=?" for f in FIELDS),
                [row[f] for f in FIELDS] + [row["hash"], stamp, rid])
        else:
            conn.execute("UPDATE events SET last_seen=?, gone=0 WHERE id=?",
                         (stamp, rid))
    gone = 0
    if rows:
        conn.execute("CREATE TEMP TABLE IF NOT EXISTS _seen (id TEXT PRIMARY KEY)")
        conn.execute("DELETE FROM _seen")
        conn.executemany("INSERT OR IGNORE INTO _seen VALUES (?)",
                         [(k,) for k in rows])
        cur = conn.execute(
            "UPDATE events SET gone=1 WHERE source=? AND gone=0"
            " AND id NOT IN (SELECT id FROM _seen)", (slug,))
        gone = cur.rowcount
        conn.execute("DELETE FROM _seen")
    return new, changed, gone


def sync_meta(conn, scrapers_dir):
    n = 0
    for slug in sorted(os.listdir(scrapers_dir)):
        p = os.path.join(scrapers_dir, slug, "meta.json")
        if not os.path.isfile(p):
            continue
        m = json.load(open(p, encoding="utf-8"))
        s = m.get("schedule") or {}
        conn.execute(
            "INSERT INTO scrapers (slug, status, method, grp, cadence, horizon_days)"
            " VALUES (?, ?, ?, ?, ?, ?)"
            " ON CONFLICT(slug) DO UPDATE SET status=excluded.status,"
            " method=excluded.method, grp=excluded.grp, cadence=excluded.cadence,"
            " horizon_days=excluded.horizon_days",
            (slug, m.get("status"), m.get("method"), m.get("group"),
             s.get("cadence") or "weekly", s.get("horizon_days") or 180))
        n += 1
    return n


def due(conn, at=None, force=False):
    at = at or dt.datetime.now()
    out = []
    for r in conn.execute("SELECT * FROM scrapers WHERE status='built'"
                          " ORDER BY slug"):
        if force or not r["last_ok"]:
            out.append(r["slug"])
            continue
        try:
            last = dt.datetime.fromisoformat(r["last_ok"])
        except ValueError:
            out.append(r["slug"])
            continue
        days = INTERVAL_DAYS.get(r["cadence"], 7)
        if at - last >= dt.timedelta(days=days):
            out.append(r["slug"])
    return out
