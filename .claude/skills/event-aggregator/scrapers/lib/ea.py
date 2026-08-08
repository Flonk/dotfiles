import html
import json
import os
import re
import sys
import urllib.request

UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")

MON = {m: i + 1 for i, m in enumerate(
    "Jänner Februar März April Mai Juni Juli August September Oktober "
    "November Dezember".split())}
MON.update({m: i + 1 for i, m in enumerate(
    "Januar Februar März April Mai Juni Juli August September Oktober "
    "November Dezember".split())})
MON.update({m: i + 1 for i, m in enumerate(
    "January February March April May June July August September October "
    "November December".split())})
MON.update({m[:3]: v for m, v in list(MON.items())})


def fetch(url, cache=None, timeout=60, headers=None):
    if cache and os.path.exists(cache):
        with open(cache, "rb") as f:
            return f.read().decode("utf-8", "replace")
    req = urllib.request.Request(url, headers={"User-Agent": UA,
                                               "Accept-Language": "de-AT,de;q=0.9,en;q=0.8",
                                               **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
    if cache:
        with open(cache, "wb") as f:
            f.write(raw)
    return raw.decode("utf-8", "replace")


def text(s):
    if s is None:
        return None
    s = re.sub(r"<(script|style)\b.*?</\1>", " ", s, flags=re.S | re.I)
    s = re.sub(r"<[^>]+>", " ", s)
    s = html.unescape(s)
    s = re.sub(r"\s+", " ", s).strip()
    return s or None


def jsonld(page):
    out = []
    for m in re.finditer(
            r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
            page, re.S | re.I):
        try:
            d = json.loads(m.group(1).strip())
        except Exception:
            continue
        stack = [d]
        while stack:
            n = stack.pop()
            if isinstance(n, list):
                stack.extend(n)
            elif isinstance(n, dict):
                out.append(n)
                stack.extend(v for v in n.values() if isinstance(v, (list, dict)))
    return out


def de_date(s, default_year=None):
    if not s:
        return None
    s = html.unescape(s).strip()
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?", s)
    if m:
        d = f"{m.group(1)}-{m.group(2)}-{m.group(3)}"
        return f"{d}T{m.group(4)}:{m.group(5)}" if m.group(4) else d
    y = mo = dy = None
    m = re.search(r"(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})", s)
    if m:
        y, mo, dy = m.group(3), int(m.group(2)), int(m.group(1))
    if mo is None:
        m = re.search(r"(\d{1,2})\.?\s*([A-Za-zÄÖÜäöü]{3,})\.?\s*(\d{4})?", s)
        if m:
            cap = m.group(2).capitalize()
            mo = MON.get(cap) or MON.get(cap[:3])
            dy, y = int(m.group(1)), m.group(3) or default_year
    if mo is None:
        m = re.search(r"(\d{1,2})\.\s*(\d{1,2})\.(?!\s*\d{4}\b)", s)
        if m:
            mo, dy, y = int(m.group(2)), int(m.group(1)), default_year
    if not (mo and dy and y):
        return None
    out = f"{int(y):04d}-{int(mo):02d}-{int(dy):02d}"
    t = re.search(r"(\d{1,2})[:.](\d{2})\s*(?:Uhr)?", s[m.end():] if m else s)
    return f"{out}T{int(t.group(1)):02d}:{t.group(2)}" if t else out


def price(s):
    if not s:
        return None, None
    raw = text(s)
    if raw and re.search(r"\b(frei|gratis|free|eintritt frei|kostenlos)\b", raw, re.I):
        return 0.0, raw
    vals = []
    norm = re.sub(r"(\d)[.,]-", r"\1", raw or "")
    for a, b in re.findall(
            r"(?:€|EUR)\s*(\d+(?:[.,]\d{1,2})?)|(\d+(?:[.,]\d{1,2})?)\s*(?:€|EUR)",
            norm):
        v = a or b
        if v:
            vals.append(float(v.replace(",", ".")))
    return (min(vals) if vals else None), raw


def district(s):
    if not s:
        return None
    m = re.search(r"\b(1[0-2][0-9]0)\b", s)
    if m and 1010 <= int(m.group(1)) <= 1230:
        return int(m.group(1))
    return None


def horizon():
    import datetime
    n = int(os.environ.get("EA_HORIZON_DAYS") or 180)
    return datetime.date.today() + datetime.timedelta(days=n)


def emit(records):
    n = 0
    for r in records:
        r = {k: v for k, v in r.items() if v is not None or k in ("start",)}
        sys.stdout.write(json.dumps(r, ensure_ascii=False) + "\n")
        n += 1
    sys.stderr.write(f"emitted {n}\n")
    return n
