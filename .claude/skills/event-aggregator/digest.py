import argparse
import datetime as dt
import re
import sys
from collections import defaultdict

import db

DEMOTE_RUN = 8
DEMOTE_SPAN = 91
LAST_CHANCE_SPAN = 30
LAST_CHANCE_LEFT = 21


def norm(t):
    t = re.sub(r"\(.*?\)|\b-?2D-?\b|OmeU|eOmU|OmU", "", t or "")
    return re.sub(r"[^a-z0-9]", "", t.lower())[:40]


def parts(r, today):
    perm = "permanent" in (r["extra"] or "")
    s = e = None
    try:
        s = dt.date.fromisoformat(r["start_at"][:10])
        if r["end_at"]:
            e = dt.date.fromisoformat(r["end_at"][:10])
    except ValueError:
        pass
    span = 10 ** 6 if perm else ((e - s).days if (s and e) else 0)
    left = (e - today).days if e else 0
    return perm, span, left


def score(r, run_len, today):
    perm, span, left = parts(r, today)
    sc = 100.0
    why = []
    if run_len >= DEMOTE_RUN:
        sc -= 60
        why.append("run×%d" % run_len)
    if perm:
        sc -= 50
        why.append("permanent")
    elif span >= DEMOTE_SPAN:
        sc -= 45
        why.append("runs %dd" % span)
    if not perm and span >= LAST_CHANCE_SPAN and 0 <= left <= LAST_CHANCE_LEFT:
        sc += 70
        why.append("LAST CHANCE %dd left" % left)
    if run_len <= 2 and span <= 1 and not perm:
        sc += 15
        why.append("one-off")
    if r["price_min"] == 0:
        sc += 5
        why.append("free")
    return sc, why


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", default=dt.date.today().isoformat())
    ap.add_argument("--limit", type=int, default=40)
    ap.add_argument("--why", action="store_true", help="show score reasons")
    a = ap.parse_args()
    today = dt.date.fromisoformat(a.date)

    conn = db.connect()
    srcs, bven, btit = db.blacklist()
    rows = [r for r in conn.execute(
        "SELECT * FROM events WHERE gone=0 AND (substr(start_at,1,10)=?"
        " OR (substr(start_at,1,10)<=? AND substr(end_at,1,10)>=?)"
        " OR (end_at IS NULL AND substr(start_at,1,10)<=? AND extra LIKE '%permanent%'))",
        (a.date, a.date, a.date, a.date))
        if r["source"] not in srcs
        and not any(x in (r["venue"] or "").lower() for x in bven)
        and not any(x in (r["title"] or "").lower() for x in btit)]

    runs = defaultdict(int)
    for r in conn.execute("SELECT title, venue FROM events WHERE gone=0"
                          " AND substr(start_at,1,10)>=?", (a.date,)):
        runs[(norm(r["title"]), r["venue"] or "")] += 1

    seen, scored = set(), []
    for r in rows:
        k = (norm(r["title"]), r["start_at"][:16])
        if k in seen:
            continue
        seen.add(k)
        rl = runs[(norm(r["title"]), r["venue"] or "")]
        sc, why = score(r, rl, today)
        scored.append((sc, why, r))
    scored.sort(key=lambda x: (-x[0], x[2]["start_at"]))

    print("%s — %d events, %d after dedupe\n" % (a.date, len(rows), len(scored)))
    for sc, why, r in scored[:a.limit]:
        t = r["start_at"][11:16] or "  ?  "
        p = r["price_min"]
        pr = "free" if p == 0 else ("%g EUR" % p if p is not None else "")
        tail = ("  [%s]" % ", ".join(why)) if a.why and why else ""
        print("%5.0f %s  %-42s %-24s %s%s" % (
            sc, t, (r["title"] or "")[:42], (r["venue"] or "")[:24], pr, tail))

    dem = sum(1 for sc, _, _ in scored if sc < 100)
    print("\n%d demoted below baseline, %d shown of %d" % (dem, min(a.limit, len(scored)), len(scored)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
