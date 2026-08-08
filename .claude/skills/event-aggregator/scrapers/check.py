import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SCHEMA = json.load(open(os.path.join(ROOT, "..", "event.schema.json"), encoding="utf-8"))
PROPS, REQ = SCHEMA["properties"], SCHEMA["required"]
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?$")


def types_of(spec):
    t = spec.get("type", "string")
    return t if isinstance(t, list) else [t]


def check_rec(r):
    errs = []
    if not isinstance(r, dict):
        return ["not an object"]
    for k in REQ:
        if r.get(k) in (None, ""):
            errs.append(f"missing required {k}")
    for k, v in r.items():
        if k not in PROPS:
            errs.append(f"unknown field {k}")
            continue
        ts, spec = types_of(PROPS[k]), PROPS[k]
        if v is None:
            if "null" not in ts:
                errs.append(f"{k} must not be null")
            continue
        ok = (("string" in ts and isinstance(v, str))
              or ("integer" in ts and isinstance(v, int) and not isinstance(v, bool))
              or ("number" in ts and isinstance(v, (int, float)) and not isinstance(v, bool))
              or ("object" in ts and isinstance(v, dict)))
        if not ok:
            errs.append(f"{k} wrong type ({type(v).__name__}, want {ts})")
            continue
        if k in ("start", "end") and isinstance(v, str) and not DATE.match(v):
            errs.append(f"{k} bad format: {v!r}")
        if "enum" in spec and v not in spec["enum"]:
            errs.append(f"{k} not in enum: {v!r}")
        if spec.get("minimum") is not None and v < spec["minimum"]:
            errs.append(f"{k} below minimum")
        if spec.get("maximum") is not None and v > spec["maximum"]:
            errs.append(f"{k} above maximum")
    return errs


def main(slug):
    d = os.path.join(ROOT, slug)
    meta = json.load(open(os.path.join(d, "meta.json"), encoding="utf-8"))
    if not os.path.exists(os.path.join(d, "scrape.py")):
        print(f"FAIL {slug}: no scrape.py")
        return 1
    horizon = (meta.get("schedule") or {}).get("horizon_days") or 180
    env = {**os.environ, "PYTHONPATH": os.path.join(ROOT, "lib"),
           "EA_HORIZON_DAYS": str(horizon)}
    p = subprocess.run([sys.executable, "scrape.py"], cwd=d, env=env,
                       capture_output=True, text=True, timeout=300)
    if p.returncode != 0:
        print(f"FAIL {slug}: scrape.py exit {p.returncode}\n{p.stderr[-2000:]}")
        return 1

    recs, bad = [], []
    for i, line in enumerate(p.stdout.splitlines()):
        if not line.strip():
            continue
        try:
            r = json.loads(line)
        except Exception as e:
            bad.append(f"line {i + 1}: not JSON ({e})")
            continue
        errs = check_rec(r)
        if errs:
            bad.append(f"line {i + 1}: " + "; ".join(errs))
        else:
            recs.append(r)

    exp = meta.get("expect") or {}
    fails = list(bad[:10])
    if bad:
        fails.append(f"({len(bad)} invalid records total)")
    lo = exp.get("min_records")
    if lo and len(recs) < lo:
        fails.append(f"only {len(recs)} valid records, expected >= {lo}")
    if not recs:
        fails.append("zero valid records")
    for k, frac in (exp.get("required_fill") or {}).items():
        got = sum(1 for r in recs if r.get(k) not in (None, "")) / max(len(recs), 1)
        if got < frac:
            fails.append(f"fill {k}={got:.0%} < {frac:.0%}")
    if all(r.get("source") == meta["slug"] for r in recs) is False:
        fails.append("source field does not match slug")

    if not fails:
        with open(os.path.join(d, "scraper_example_result.json"), "w",
                  encoding="utf-8") as f:
            json.dump(recs, f, indent=2, ensure_ascii=False)
            f.write("\n")

    status = "FAIL" if fails else "PASS"
    print(f"{status} {slug}: {len(recs)} valid, {len(bad)} invalid")
    for f in fails:
        print(f"  - {f}")
    return 1 if fails else 0


if __name__ == "__main__":
    targets = sys.argv[1:] or sorted(
        n for n in os.listdir(ROOT)
        if os.path.isdir(os.path.join(ROOT, n)) and n != "lib")
    sys.exit(max(main(s) for s in targets))
