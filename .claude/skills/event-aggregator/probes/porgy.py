import re, html, datetime as dt

s = open("pu.html", encoding="utf-8", errors="replace").read()
MON = {m: i + 1 for i, m in enumerate(
    "Jänner Februar März April Mai Juni Juli August September Oktober November Dezember".split())}

pat = re.compile(
    r'<div class="date">(.*?)</div>.*?'
    r'<div class="time">(.*?)</div>.*?'
    r'(?:<div class="zyklus"\s*>\s*(.*?)</div>)?.*?'
    r'<div class="title"\s*>\s*<a href="([^"]+)">(.*?)</a>', re.S)

today = dt.date(2026, 8, 7)
end = today + dt.timedelta(days=8)


def clean(x):
    return html.unescape(re.sub("<[^>]+>", "", x or "")).strip()


rows = []
for d, t, z, href, title in pat.findall(s):
    m = re.search(r'(\d{1,2})\.\s*(\w+)\s*(\d{4})', html.unescape(d))
    if not m:
        continue
    day = dt.date(int(m.group(3)), MON.get(m.group(2), 1), int(m.group(1)))
    if today <= day < end:
        rows.append((day, t.strip(), clean(z), clean(title), href))

rows.sort()
print(f"{len(rows)} Porgy & Bess events, {today} .. {end - dt.timedelta(days=1)}\n")
for day, t, z, title, href in rows:
    tag = f"  [{z}]" if z else ""
    print(f"{day} {day.strftime('%a')} {t:>5}  {title[:70]}{tag}")
