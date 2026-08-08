import datetime as dt
import json
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
BUDGET = 2000
CAD_DAYS = {"daily": 1, "weekly": 7, "monthly": 30}
PRIOR = {
    "aggregator": "daily", "city": "daily", "bargain": "daily", "ticketing": "daily",
    "music": "weekly", "cinema": "weekly", "theatre": "weekly", "congress": "weekly",
    "academic": "weekly", "literature": "weekly", "society": "weekly",
    "museum": "monthly", "filmfest": "monthly", "fair": "monthly",
    "food": "monthly", "sport": "monthly",
}
PRIOR_HORIZON = {"daily": 30, "weekly": 90, "monthly": 180}
CAD_ORDER = ["daily", "weekly", "monthly"]


def pct(xs, p):
    if not xs:
        return None
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(round(p * (len(xs) - 1))))]


def measure(path, today):
    starts, closes = [], []
    for rec in json.load(open(path, encoding="utf-8")):
        try:
            s = dt.date.fromisoformat(rec["start"][:10])
        except Exception:
            continue
        starts.append(s)
        try:
            closes.append(dt.date.fromisoformat((rec.get("end") or "")[:10]))
        except Exception:
            closes.append(s)
    if len(starts) < 3:
        return None
    span = max((max(starts) - min(starts)).days, 1)
    density = len(starts) / span
    leads = [(d - today).days for d in starts if (d - today).days >= 0]
    # How far ahead the published programme reaches. An exhibition that opened
    # last year still occupies the calendar until it closes, so this has to
    # follow `end` where there is one - otherwise a museum whose every start is
    # in the past looks like a source with a one-day window.
    reach = [(d - today).days for d in closes if (d - today).days >= 0]
    return (density, (pct(leads, 0.95) or 0), len(starts),
            (max(leads) if leads else 0), (max(reach) if reach else None))


def stricter(a, b):
    return CAD_ORDER[min(CAD_ORDER.index(a), CAD_ORDER.index(b))]


def window_cadence(reach):
    """How fast the published window turns over.

    Density is events-per-day, which conflates "few events" with "short
    window". A cinema listing 7 films over the next 3 days is not a low-churn
    source — it is a source whose entire programme is replaced within the week.
    Scraping that monthly misses three weeks in four.

    `reach` of None means nothing on the page is still ahead of us, which is not
    evidence either way, so the rule abstains rather than guessing.
    """
    if reach is None:
        return None
    if reach <= 10:
        return "daily"
    if reach <= 45:
        return "weekly"
    return "monthly"


def schedule(density, p95_lead, truncated=False, reach=None, prior=None):
    cadence = "daily" if density >= 5 else "weekly" if density >= 0.3 else "monthly"
    win = window_cadence(reach)
    if win:
        cadence = stricter(cadence, win)
    # The group prior is a floor. One snapshot can show that a source is busier
    # than its kind usually is, but it cannot show the opposite: a quiet week at
    # a cinema is a quiet week, not a cinema that stopped turning over. So
    # measurement may tighten the prior, never loosen it.
    if prior:
        cadence = stricter(cadence, prior)
    h = BUDGET / max(density, 0.01)
    h = max(30.0, min(180.0, h))
    if p95_lead > 0 and not truncated:
        h = min(h, p95_lead * 1.2)
    h = max(h, 2 * CAD_DAYS[cadence])
    return cadence, int(round(h))


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("-")]
    dry = "--dry" in argv[1:]
    skip = set(args)
    today = dt.date.today()
    rows = []
    changed = []
    for slug in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, slug)
        mp = os.path.join(d, "meta.json")
        if slug in ("lib", "__pycache__") or slug in skip or not os.path.isfile(mp):
            continue
        meta = json.load(open(mp, encoding="utf-8"))
        sample = os.path.join(d, "scraper_example_result.json")
        m = measure(sample, today) if os.path.isfile(sample) else None
        if m:
            density, p95, n, max_lead, reach = m
            used = (meta.get("schedule") or {}).get("horizon_days") or 180
            truncated = max_lead >= used
            cadence, horizon = schedule(density, p95, truncated, reach,
                                        PRIOR.get(meta.get("group")))
            sched = {"cadence": cadence, "horizon_days": horizon, "basis": "measured",
                     "density_per_day": round(density, 3), "p95_lead_days": p95,
                     "sample_records": n, "sample_truncated": truncated,
                     "reach_days": reach}
        else:
            cadence = PRIOR.get(meta.get("group"), "weekly")
            sched = {"cadence": cadence, "horizon_days": PRIOR_HORIZON[cadence],
                     "basis": "prior", "density_per_day": None,
                     "p95_lead_days": None, "sample_records": 0}
        was = (meta.get("schedule") or {}).get("cadence")
        if was and was != sched["cadence"]:
            changed.append((slug, meta.get("group"), was, sched["cadence"],
                            sched.get("sample_records")))
        meta["schedule"] = sched
        if not dry:
            with open(mp, "w", encoding="utf-8") as f:
                json.dump(meta, f, indent=2, ensure_ascii=False)
                f.write("\n")
        rows.append((slug, meta.get("group"), sched))

    tally = {}
    for _, _, s in rows:
        k = (s["cadence"], s["basis"])
        tally[k] = tally.get(k, 0) + 1
    for k in sorted(tally):
        print(f"{k[0]:8} {k[1]:8} {tally[k]}")
    print(f"total {len(rows)}{' (dry run, nothing written)' if dry else ''}")
    if changed:
        print(f"\n{len(changed)} cadence changes")
        for slug, grp, was, now, n in changed:
            print(f"  {slug:22} {str(grp):10} {was:8} -> {now:8}  n={n}")


if __name__ == "__main__":
    main(sys.argv)
