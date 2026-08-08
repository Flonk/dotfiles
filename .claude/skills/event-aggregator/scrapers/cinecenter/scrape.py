import datetime
import re
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import ea

BASE = "https://ticket.cinecenter.at/control/res_main.aspx"

VS_RE = {
    "__VIEWSTATE": re.compile(r'name="__VIEWSTATE" id="__VIEWSTATE" value="([^"]*)"'),
    "__VIEWSTATEGENERATOR": re.compile(
        r'name="__VIEWSTATEGENERATOR" id="__VIEWSTATEGENERATOR" value="([^"]*)"'),
    "__EVENTVALIDATION": re.compile(
        r'name="__EVENTVALIDATION" id="__EVENTVALIDATION" value="([^"]*)"'),
}

FILM_BLOCK = re.compile(
    r'<tr class="sinemaPrg times">(.*?)</tr>\s*<tr>(.*?)</tr>\s*<tr>\s*<td colspan="10">',
    re.S)
FILM_ID = re.compile(r"res_main\.aspx\?op=info&ID=(\d+)")
TITLE_VERSION = re.compile(
    r"<td>\s*<b><a[^>]*>\s*(.*?)\s*</a></b>\s*<br />\s*(.*?)\s*</td>", re.S)
SHOWTIME = re.compile(
    r"href='res_main\.aspx\?op=res&PrgID=(\d+)' title='(\d{2}:\d{2}) - "
    r"(\d{2}:\d{2}) \((\d+) min\)'>\d{2}:\d{2} ([^<&]*)")
SELECTED_DATE = re.compile(r'<option selected="selected" value="([\d.]+)"')
OPTION_DATE = re.compile(r'<option[^>]*value="([\d.]+)">')
GENRE_RE = re.compile(r"Genre</b></td><td class='sinemaFilmInfo col2'>([^<]*)</td>")
IMG_RE = re.compile(r'class="image_container[^"]*">\s*<img[^>]+src="([^"]+)"')
H1_RE = re.compile(r"<h1>(.*?)<span", re.S)
DESC_RE = re.compile(r'class="sinemaFilmInfoArea ce_text">.*?<p>(.*?)</p>', re.S)


def post_week(target_date, viewstate, vgen, evalid):
    form = {
        "__EVENTTARGET": "prg1$ddDatePicker",
        "__EVENTARGUMENT": "",
        "__VIEWSTATE": viewstate,
        "__VIEWSTATEGENERATOR": vgen,
        "__EVENTVALIDATION": evalid,
        "prg1$ddDatePicker": target_date,
    }
    body = urllib.parse.urlencode(form).encode()
    req = urllib.request.Request(
        BASE + "?PrgMode=2", data=body,
        headers={"User-Agent": ea.UA, "Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")


def parse_week(html):
    m = SELECTED_DATE.search(html)
    if not m:
        return []
    dd, mm, yyyy = m.group(1).split(".")
    anchor = datetime.date(int(yyyy), int(mm), int(dd))
    out = []
    for header, row in FILM_BLOCK.findall(html):
        fm = FILM_ID.search(header)
        if not fm:
            continue
        film_id = fm.group(1)
        tv = TITLE_VERSION.search(header)
        title = ea.text(tv.group(1)) if tv else None
        version = ea.text(tv.group(2)) if tv else None
        if not title:
            continue

        parts = row.split("<td valign='top'>")[1:8]
        for i, part in enumerate(parts):
            day = anchor + datetime.timedelta(days=i)
            for sm in SHOWTIME.finditer(part):
                prg_id, start, end, dur, room = sm.groups()
                out.append({
                    "film_id": film_id,
                    "title": title,
                    "version": version,
                    "date": day,
                    "start": start,
                    "end": end,
                    "duration_min": dur,
                    "room": room.strip().rstrip("\xa0").strip(),
                    "prg_id": prg_id,
                })
    return out


def film_meta(film_id):
    html = None
    for attempt in range(4):
        try:
            html = ea.fetch(f"{BASE}?op=info&ID={film_id}", timeout=30)
            break
        except Exception as e:
            sys.stderr.write(f"film_meta {film_id} attempt {attempt} failed: {e}\n")
    if html is None:
        return film_id, {"genre": None, "description": None, "image": None}
    genre = None
    gm = GENRE_RE.search(html)
    if gm:
        genre = ea.text(gm.group(1))
    desc = None
    dm = DESC_RE.search(html)
    if dm:
        desc = ea.text(dm.group(1).split("<br><bR>")[0].split("<br><br>")[0])
    image = None
    im = IMG_RE.search(html)
    if im:
        image = im.group(1)
    return film_id, {"genre": genre, "description": desc, "image": image}


def main():
    horizon = ea.horizon()
    first = ea.fetch(BASE + "?PrgMode=2")
    shows = parse_week(first)

    viewstate = VS_RE["__VIEWSTATE"].search(first).group(1)
    vgen = VS_RE["__VIEWSTATEGENERATOR"].search(first).group(1)
    evalid = VS_RE["__EVENTVALIDATION"].search(first).group(1)

    seen_anchors = set()
    m = SELECTED_DATE.search(first)
    if m:
        seen_anchors.add(m.group(1))

    for opt in OPTION_DATE.findall(first):
        if opt in seen_anchors:
            continue
        dd, mm, yyyy = opt.split(".")
        opt_date = datetime.date(int(yyyy), int(mm), int(dd))
        if opt_date > horizon:
            continue
        try:
            page = post_week(opt, viewstate, vgen, evalid)
        except Exception as e:
            sys.stderr.write(f"postback {opt} failed: {e}\n")
            continue
        shows.extend(parse_week(page))
        seen_anchors.add(opt)

    seen_prg = set()
    dedup_shows = []
    for s in shows:
        if s["prg_id"] in seen_prg:
            continue
        seen_prg.add(s["prg_id"])
        if s["date"] > horizon:
            continue
        dedup_shows.append(s)

    film_ids = sorted({s["film_id"] for s in dedup_shows})
    cache = {}
    if film_ids:
        with ThreadPoolExecutor(max_workers=8) as ex:
            for film_id, meta in ex.map(film_meta, film_ids):
                cache[film_id] = meta

    records = []
    for s in dedup_shows:
        meta = cache.get(s["film_id"], {"genre": None, "description": None, "image": None})
        start_dt = f"{s['date'].isoformat()}T{s['start']}"
        title = s["title"]
        cat = meta["genre"]
        records.append({
            "source": "cinecenter",
            "source_id": s["prg_id"],
            "url": f"{BASE}?op=info&ID={s['film_id']}",
            "title": title,
            "start": start_dt,
            "end": None,
            "venue": f"CineCenter {s['room']}" if s["room"] else "CineCenter",
            "district": 1010,
            "city": "Wien",
            "address": "Fleischmarkt 6, 1010 Wien",
            "price_min": None,
            "price_text": None,
            "category": cat,
            "description": meta["description"],
            "image": meta["image"],
            "status": "scheduled",
            "extra": {
                "version": s["version"],
                "duration_min": int(s["duration_min"]),
                "room": s["room"],
            },
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
