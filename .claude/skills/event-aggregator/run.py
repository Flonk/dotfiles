import argparse
import concurrent.futures as cf
import json
import os
import subprocess
import sys

import db

ROOT = os.path.dirname(os.path.abspath(__file__))
SCRAPERS = os.path.join(ROOT, "scrapers")
sys.path.insert(0, SCRAPERS)
import check  # noqa: E402


def scrape(slug, horizon, timeout=600):
    d = os.path.join(SCRAPERS, slug)
    env = {**os.environ, "PYTHONPATH": os.path.join(SCRAPERS, "lib"),
           "EA_HORIZON_DAYS": str(horizon or 180)}
    p = subprocess.run([sys.executable, "scrape.py"], cwd=d, env=env,
                       capture_output=True, text=True, timeout=timeout)
    if p.returncode != 0:
        raise RuntimeError("exit %d: %s" % (p.returncode, p.stderr[-800:].strip()))
    valid, invalid = [], 0
    for line in p.stdout.splitlines():
        if not line.strip():
            continue
        try:
            r = json.loads(line)
        except ValueError:
            invalid += 1
            continue
        if check.check_rec(r):
            invalid += 1
        else:
            valid.append(r)
    if not valid:
        raise RuntimeError("zero valid records (%d invalid)" % invalid)
    return valid, invalid


def from_sample(slug):
    f = os.path.join(SCRAPERS, slug, "scraper_example_result.json")
    if not os.path.isfile(f):
        raise RuntimeError("no sample file")
    return json.load(open(f, encoding="utf-8")), 0


def one(slug, horizon, seed):
    return from_sample(slug) if seed else scrape(slug, horizon)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("slugs", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--seed", action="store_true",
                    help="ingest scraper_example_result.json instead of scraping")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--jobs", type=int, default=4)
    a = ap.parse_args()

    conn = db.connect()
    db.sync_meta(conn, SCRAPERS)
    conn.commit()

    if a.slugs:
        todo = a.slugs
    else:
        todo = db.due(conn, force=a.all or a.seed)
    horizons = {r["slug"]: r["horizon_days"]
                for r in conn.execute("SELECT slug, horizon_days FROM scrapers")}

    if a.dry:
        for s in todo:
            print(s)
        print("%d due" % len(todo))
        return 0

    if not todo:
        print("nothing due")
        return 0

    ok = fail = 0
    with cf.ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
        futs = {ex.submit(one, s, horizons.get(s), a.seed): s for s in todo}
        for fut in cf.as_completed(futs):
            slug = futs[fut]
            stamp = db.now()
            cur = conn.execute(
                "INSERT INTO runs (slug, started_at) VALUES (?, ?)", (slug, stamp))
            run_id = cur.lastrowid
            try:
                recs, invalid = fut.result()
                new, changed, gone = db.ingest(conn, slug, recs, stamp)
                conn.execute(
                    "UPDATE runs SET finished_at=?, ok=1, n_valid=?, n_invalid=?,"
                    " n_new=?, n_changed=?, n_gone=? WHERE id=?",
                    (db.now(), len(recs), invalid, new, changed, gone, run_id))
                conn.execute(
                    "UPDATE scrapers SET last_run=?, last_ok=?, last_count=?,"
                    " last_error=NULL, fail_streak=0 WHERE slug=?",
                    (stamp, stamp, len(recs), slug))
                ok += 1
                print("ok   %-22s %5d rec  +%d ~%d -%d" %
                      (slug, len(recs), new, changed, gone))
            except Exception as e:
                msg = str(e)[:500]
                conn.execute(
                    "UPDATE runs SET finished_at=?, ok=0, error=? WHERE id=?",
                    (db.now(), msg, run_id))
                conn.execute(
                    "UPDATE scrapers SET last_run=?, last_error=?,"
                    " fail_streak=fail_streak+1 WHERE slug=?", (stamp, msg, slug))
                fail += 1
                print("FAIL %-22s %s" % (slug, msg.splitlines()[0][:90]))
            conn.commit()

    live = conn.execute("SELECT COUNT(*) FROM events WHERE gone=0").fetchone()[0]
    print("\n%d ok, %d failed | %d live events" % (ok, fail, live))
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
