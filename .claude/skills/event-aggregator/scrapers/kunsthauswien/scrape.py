import datetime
import json
import urllib.request
import zoneinfo

import ea

API = "https://www.kunsthauswien.com/api/"
TZ = zoneinfo.ZoneInfo("Europe/Vienna")

VENUE = "KunstHausWien"
ADDRESS = "Weißgerberstraße 13"
DISTRICT = 1030

QUERY_EXHIBITIONS = """
query FetchExhibitions($endDate: [QueryArgument]) {
  entries(section: ["exhibitions"], language: ["de-AT"], endDate: $endDate) {
    id
    title
    url
    subtitleText
    startDate
    endDate
  }
}
"""

QUERY_DATES = """
query FetchDateEntries($date: [QueryArgument], $limit: Int!, $offset: Int!) {
  dateEntries: entries(
    type: "date"
    date: $date
    limit: $limit
    offset: $offset
    orderBy: "date ASC, id DESC"
  ) {
    id
    ownerId
    ... on date_Entry {
      date
      startTime
      endTime
      detailsText
      eventType { id title }
    }
  }
  dateCount: entryCount(type: "date" date: $date)
}
"""

QUERY_EVENTS = """
query FetchEventByIds($ids: [QueryArgument], $siteLanguage: [String]) {
  eventsEntries: entries(id: $ids, section: ["events"], language: $siteLanguage) {
    id
    ... on event_Entry {
      id
      url
      title
      subtitleText
      startTime
      endTime
      detailsText
      bookingType
    }
  }
}
"""


def gql(query, variables):
    body = json.dumps({"query": query, "variables": variables}).encode()
    req = urllib.request.Request(API, data=body, headers={
        "User-Agent": ea.UA,
        "Content-Type": "application/json",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.loads(r.read().decode("utf-8"))
    if data.get("errors"):
        raise RuntimeError(str(data["errors"]))
    return data["data"]


def local_date(iso_str):
    if not iso_str:
        return None
    dt = datetime.datetime.fromisoformat(iso_str)
    return dt.astimezone(TZ).date()


def local_time_hm(iso_str):
    if not iso_str:
        return None
    dt = datetime.datetime.fromisoformat(iso_str)
    return dt.astimezone(TZ).strftime("%H:%M")


def combine(date_obj, hm):
    d = date_obj.isoformat()
    return f"{d}T{hm}" if hm else d


def exhibition_records(cutoff):
    today = datetime.date.today().isoformat()
    data = gql(QUERY_EXHIBITIONS, {"endDate": [f">= {today}"]})
    out = []
    for e in data["entries"]:
        start = local_date(e["startDate"])
        end = local_date(e["endDate"])
        if start is None:
            continue
        out.append({
            "source": "kunsthauswien",
            "source_id": str(e["id"]),
            "url": e["url"],
            "title": e["title"],
            "start": start.isoformat(),
            "end": end.isoformat() if end else None,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": "Ausstellung",
            "description": e.get("subtitleText"),
            "status": "scheduled",
        })
    return out


def permanent_record():
    today = datetime.date.today().isoformat()
    return {
        "source": "kunsthauswien",
        "source_id": "museum-hundertwasser",
        "url": "https://www.kunsthauswien.com/museum-hundertwasser",
        "title": "Museum Hundertwasser",
        "start": today,
        "end": None,
        "venue": VENUE,
        "district": DISTRICT,
        "city": "Wien",
        "address": ADDRESS,
        "price_min": None,
        "price_text": None,
        "category": "Ausstellung",
        "description": ("Die weltweit größte Sammlung von Friedensreich "
                         "Hundertwassers Werken."),
        "status": "scheduled",
        "extra": {"permanent": True},
    }


def date_entries(cutoff):
    today = datetime.date.today().isoformat()
    limit = 100
    offset = 0
    out = []
    while True:
        data = gql(QUERY_DATES, {
            "date": ["AND", f">= {today}"],
            "limit": limit,
            "offset": offset,
        })
        entries = data["dateEntries"]
        total = data["dateCount"]
        out.extend(entries)
        offset += limit
        if offset >= total or not entries:
            break
    kept = []
    for e in out:
        d = local_date(e["date"])
        if d and d <= cutoff:
            kept.append(e)
    return kept


def event_details(owner_ids):
    if not owner_ids:
        return {}
    data = gql(QUERY_EVENTS, {"ids": owner_ids, "siteLanguage": ["de-AT"]})
    return {str(ev["id"]): ev for ev in data["eventsEntries"]}


def program_records(cutoff):
    dates = date_entries(cutoff)
    owner_ids = sorted(set(str(d["ownerId"]) for d in dates))
    events = event_details(owner_ids)

    out = []
    for d in dates:
        ev = events.get(str(d["ownerId"]))
        if not ev:
            continue
        day = local_date(d["date"])
        if day is None:
            continue

        hm_start = local_time_hm(d.get("startTime")) or local_time_hm(ev.get("startTime"))
        hm_end = local_time_hm(d.get("endTime")) or local_time_hm(ev.get("endTime"))

        title = ev.get("title")
        if not title:
            continue

        category = None
        et = d.get("eventType")
        if et:
            category = et[0].get("title")

        description = d.get("detailsText") or ev.get("subtitleText") or ev.get("detailsText")

        out.append({
            "source": "kunsthauswien",
            "source_id": f"date-{d['id']}",
            "url": ev.get("url"),
            "title": title,
            "start": combine(day, hm_start),
            "end": combine(day, hm_end) if hm_end else None,
            "venue": VENUE,
            "district": DISTRICT,
            "city": "Wien",
            "address": ADDRESS,
            "price_min": None,
            "price_text": None,
            "category": category,
            "description": description,
            "status": "scheduled",
        })
    return out


def main():
    cutoff = ea.horizon()
    records = exhibition_records(cutoff) + [permanent_record()] + program_records(cutoff)
    ea.emit(records)


if __name__ == "__main__":
    main()
