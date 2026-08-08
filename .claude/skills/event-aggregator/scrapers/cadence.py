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


def pct(xs, p):
    if not xs:
        return None
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(round(p * (len(xs) - 1))))]


def measure(path, today):
    starts = []
    for rec in json.load(open(path, encoding="utf-8")):
        try:
            starts.append(dt.date.fromisoformat(rec["start"][:10]))
        except Exception:
            continue
    if len(starts) < 3:
        return None
    span = max((max(starts) - min(starts)).days, 1)
    density = len(starts) / span
    leads = [(d - today).days for d in starts if (d - today).days >= 0]
    return density, (pct(leads, 0.95) or 0), len(starts), (max(leads) if leads else 0)


def schedule(density, p95_lead, truncated=False):
    cadence = "daily" if density >= 5 else "weekly" if density >= 0.3 else "monthly"
    h = BUDGET / max(density, 0.01)
    h = max(30.0, min(180.0, h))
    if p95_lead > 0 and not truncated:
        h = min(h, p95_lead * 1.2)
    h = max(h, 2 * CAD_DAYS[cadence])
    return cadence, int(round(h))


def main(argv):
    skip = set(argv[1:])
    today = dt.date.today()
    rows = []
    for slug in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, slug)
        mp = os.path.join(d, "meta.json")
        if slug in ("lib", "__pycache__") or slug in skip or not os.path.isfile(mp):
            continue
        meta = json.load(open(mp, encoding="utf-8"))
        sample = os.path.join(d, "scraper_example_result.json")
        m = measure(sample, today) if os.path.isfile(sample) else None
        if m:
            density, p95, n, max_lead = m
            used = (meta.get("schedule") or {}).get("horizon_days") or 180
            truncated = max_lead >= used
            cadence, horizon = schedule(density, p95, truncated)
            sched = {"cadence": cadence, "horizon_days": horizon, "basis": "measured",
                     "density_per_day": round(density, 3), "p95_lead_days": p95,
                     "sample_records": n, "sample_truncated": truncated}
        else:
            cadence = PRIOR.get(meta.get("group"), "weekly")
            sched = {"cadence": cadence, "horizon_days": PRIOR_HORIZON[cadence],
                     "basis": "prior", "density_per_day": None,
                     "p95_lead_days": None, "sample_records": 0}
        meta["schedule"] = sched
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
    print(f"total {len(rows)}")


if __name__ == "__main__":
    main(sys.argv)
