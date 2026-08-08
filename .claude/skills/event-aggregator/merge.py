import datetime as dt
import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SCRAPERS = os.path.join(ROOT, "scrapers")
RUNTIME_KEYS = ("duration_min", "duration_text", "Länge", "runtime",
                "origin_year_runtime")


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


def load():
    out = []
    for slug in sorted(os.listdir(SCRAPERS)):
        f = os.path.join(SCRAPERS, slug, "scraper_example_result.json")
        if not os.path.isfile(f):
            continue
        for r in json.load(open(f, encoding="utf-8")):
            r["uid"] = hashlib.sha1(
                ("%s:%s" % (r["source"], r["source_id"])).encode()).hexdigest()[:12]
            e = derive_end(r)
            if e:
                r["end"] = e
                r.setdefault("extra", {})["end_derived"] = True
            out.append(r)
    return out


def main():
    recs = load()
    dest = os.path.join(ROOT, "events.json")
    with open(dest, "w", encoding="utf-8") as f:
        json.dump(recs, f, indent=1, ensure_ascii=False)
        f.write("\n")
    timed = sum(1 for r in recs if "T" in (r.get("start") or ""))
    ends = sum(1 for r in recs if "T" in (r.get("end") or ""))
    derived = sum(1 for r in recs if (r.get("extra") or {}).get("end_derived"))
    print(f"{len(recs)} records -> {dest}")
    print(f"timed starts {timed} | end times {ends} (derived {derived})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
