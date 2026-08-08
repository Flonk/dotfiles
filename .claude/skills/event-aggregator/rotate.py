import argparse
import re
import sys
from collections import defaultdict

import db

MIN_RUN = 3


def norm(t):
    t = re.sub(r"\(.*?\)|\b-?2D-?\b|OmeU|eOmU|OmU", "", t or "")
    return re.sub(r"[^a-z0-9]", "", t.lower())[:40]


def blocks(conn, slug, gone):
    out = defaultdict(list)
    for r in conn.execute(
            "SELECT title, venue, start_at, first_seen FROM events"
            " WHERE source=? AND gone=?", (slug, 1 if gone else 0)):
        out[(norm(r["title"]), r["venue"] or "")].append(r)
    return out


def since_stamp(conn, slug):
    row = conn.execute(
        "SELECT started_at FROM runs WHERE slug=? AND ok=1"
        " ORDER BY id DESC LIMIT 1 OFFSET 1", (slug,)).fetchone()
    return row["started_at"] if row else None


def report(conn, slug, min_run):
    prev = since_stamp(conn, slug)
    live = blocks(conn, slug, gone=False)
    dead = blocks(conn, slug, gone=True)

    entered = []
    for k, v in live.items():
        if len(v) < min_run:
            continue
        first = min(r["first_seen"] for r in v)
        if prev and first > prev:
            entered.append((v[0]["title"], v[0]["venue"], len(v),
                            min(r["start_at"][:10] for r in v)))
    left = [(v[0]["title"], v[0]["venue"], len(v))
            for k, v in dead.items() if len(v) >= min_run and k not in live]
    return prev, entered, left


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("slugs", nargs="*")
    ap.add_argument("--min-run", type=int, default=MIN_RUN)
    ap.add_argument("--all", action="store_true",
                    help="include sources with no rotation change")
    a = ap.parse_args()

    conn = db.connect()
    srcs, _, _ = db.blacklist()
    todo = a.slugs or [r["slug"] for r in conn.execute(
        "SELECT slug FROM scrapers WHERE status='built' ORDER BY slug")
        if r["slug"] not in srcs]

    shown = 0
    for slug in todo:
        prev, entered, left = report(conn, slug, a.min_run)
        if not entered and not left and not a.all:
            continue
        shown += 1
        note = "" if prev else "  (only one run on record - nothing to diff yet)"
        print("== %s ==%s" % (slug, note))
        for t, v, n, d in entered:
            print("   + %-46s %2d dates from %s" % (t[:46], n, d))
        for t, v, n in left:
            print("   - %-46s %2d dates dropped" % (t[:46], n))
        if not entered and not left:
            print("   (no change)")
        print()

    if not shown:
        print("no rotation changes (run length >= %d)" % a.min_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
