import datetime
import json
import re
import zoneinfo

import ea

URL = "https://www.aurena.at/auktionen"
STATE_KEY = "package:/180210963@"
VIENNA = zoneinfo.ZoneInfo("Europe/Vienna")


def decode_state(raw):
    raw = raw.replace("&q;", '"').replace("&a;", "&").replace("&l;", "<").replace("&g;", ">")
    return json.loads(raw)


def local_dt(ms):
    if ms is None:
        return None
    dt = datetime.datetime.fromtimestamp(ms / 1000, VIENNA)
    if dt.hour == 0 and dt.minute == 0:
        return dt.strftime("%Y-%m-%d")
    return dt.strftime("%Y-%m-%dT%H:%M")


def main():
    page = ea.fetch(URL)
    m = re.search(
        r'<script id=bidware-state type=application/json>(.*?)</script>',
        page, re.S)
    if not m:
        return
    state = decode_state(m.group(1))

    items = None
    for k, v in state.items():
        if k.startswith(STATE_KEY) and isinstance(v, dict) and "items" in v:
            its = v["items"]
            if its and "langData" in its[0]:
                items = its
                break
    if not items:
        return

    records = []
    for it in items:
        aid = it.get("auctionId")
        if aid is None:
            continue
        lang = it.get("langData", {})
        title = (lang.get("titles") or {}).get("de_DE")
        if not title:
            continue
        ti = it.get("timeInfo") or {}
        start = local_dt(ti.get("startingDate"))
        end = local_dt(ti.get("endingDate"))
        if not start:
            continue

        loc = it.get("location") or {}
        state_code = loc.get("state")
        zip_code = loc.get("zipCode")
        city = loc.get("city")
        is_ship = state_code == "SHIP" or city in (None, "0")

        district = None
        if not is_ship and zip_code:
            district = ea.district(str(zip_code))

        venue = None if is_ship else city
        address = None
        if not is_ship:
            street = loc.get("street")
            street_no = loc.get("streetNumber")
            if street and street not in ("0",):
                address = f"{street} {street_no or ''}".strip()
                if zip_code and city:
                    address += f", {zip_code} {city}"
            elif zip_code and city:
                address = f"{zip_code} {city}"

        cat = (lang.get("categoryDescriptions") or {}).get("de_DE")
        desc = (lang.get("shortDescriptions") or {}).get("de_DE") or \
            (lang.get("descriptions") or {}).get("de_DE")

        records.append({
            "source": "aurena",
            "source_id": str(aid),
            "url": f"https://www.aurena.at/auktion/{aid}",
            "title": title,
            "start": start,
            "end": end,
            "venue": venue,
            "district": district,
            "city": None if is_ship else (city or None),
            "address": address,
            "price_min": None,
            "price_text": None,
            "category": cat or None,
            "description": desc or None,
            "extra": {
                "lot_count": it.get("lotCount"),
                "shipping": is_ship,
            },
        })

    ea.emit(records)


if __name__ == "__main__":
    main()
