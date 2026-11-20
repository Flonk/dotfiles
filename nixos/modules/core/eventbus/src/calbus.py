import http.server
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.parse
import webbrowser
from datetime import datetime, timedelta, timezone

import paho.mqtt.client as mqtt
import requests

SCOPE = "https://www.googleapis.com/auth/calendar.readonly"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
API = "https://www.googleapis.com/calendar/v3"
STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "calbus")
STATE_FILE = os.path.join(STATE_DIR, "state.json")
BROKER = os.environ.get("CALBUS_BROKER", "127.0.0.1")
PORT = int(os.environ.get("CALBUS_PORT", "1883"))
CALENDARS = [c for c in os.environ.get("CALBUS_CALENDARS", "primary").split(",") if c]
SOON = timedelta(minutes=int(os.environ.get("CALBUS_SOON_MINUTES", "10")))
POLL = timedelta(seconds=int(os.environ.get("CALBUS_POLL_SECONDS", "60")))
HORIZON = timedelta(days=7)
GRACE = timedelta(minutes=5)
TICK = 5


def log(*args):
    print(*args, flush=True)


def keyring_get(key):
    r = subprocess.run(["secret-tool", "lookup", "service", "calbus", "key", key], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 and r.stdout else None


def keyring_set(key, value):
    subprocess.run(
        ["secret-tool", "store", "--label", f"calbus {key}", "service", "calbus", "key", key],
        input=value,
        text=True,
        check=True,
    )


def iso(dt):
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_time(t):
    if "dateTime" in t:
        return datetime.fromisoformat(t["dateTime"].replace("Z", "+00:00"))
    return datetime.fromisoformat(t["date"]).astimezone()


def auth(client_path):
    with open(client_path) as f:
        raw = json.load(f)
    c = raw.get("installed") or raw.get("web") or raw
    client = {"client_id": c["client_id"], "client_secret": c["client_secret"]}
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            result.update({k: v[0] for k, v in q.items()})
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write("calbus is authorized, you can close this tab.".encode())

        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    redirect = f"http://127.0.0.1:{server.server_port}"
    state = secrets.token_urlsafe(16)
    url = AUTH_URL + "?" + urllib.parse.urlencode({
        "client_id": client["client_id"],
        "redirect_uri": redirect,
        "response_type": "code",
        "scope": SCOPE,
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
    })
    log("Opening the Google consent page. If no browser opens, visit:\n" + url)
    webbrowser.open(url)
    while "code" not in result and "error" not in result:
        server.handle_request()
    if "error" in result:
        sys.exit(f"Google refused: {result['error']}")
    if result.get("state") != state:
        sys.exit("State mismatch, aborting.")
    r = requests.post(TOKEN_URL, data={
        "code": result["code"],
        "client_id": client["client_id"],
        "client_secret": client["client_secret"],
        "redirect_uri": redirect,
        "grant_type": "authorization_code",
    }, timeout=30)
    r.raise_for_status()
    token = r.json()
    if "refresh_token" not in token:
        sys.exit("Google returned no refresh token.")
    keyring_set("client", json.dumps(client))
    keyring_set("refresh_token", token["refresh_token"])
    log("Stored the client and refresh token in the keyring.")


class Google:
    def __init__(self):
        self.token = None
        self.expires = 0

    def access_token(self):
        if self.token and time.time() < self.expires - 60:
            return self.token
        client = keyring_get("client")
        refresh = keyring_get("refresh_token")
        if not client or not refresh:
            raise RuntimeError("not authorized, run `skynet calendar auth`")
        client = json.loads(client)
        r = requests.post(TOKEN_URL, data={
            "client_id": client["client_id"],
            "client_secret": client["client_secret"],
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        }, timeout=30)
        if r.status_code == 400 and r.json().get("error") == "invalid_grant":
            raise RuntimeError("refresh token revoked or expired, run `skynet calendar auth`")
        r.raise_for_status()
        d = r.json()
        self.token = d["access_token"]
        self.expires = time.time() + d.get("expires_in", 3600)
        return self.token

    def events(self, calendar, start, end):
        items, page = [], None
        while True:
            params = {
                "timeMin": iso(start),
                "timeMax": iso(end),
                "singleEvents": "true",
                "orderBy": "startTime",
                "maxResults": 250,
            }
            if page:
                params["pageToken"] = page
            r = requests.get(
                f"{API}/calendars/{urllib.parse.quote(calendar, safe='')}/events",
                params=params,
                headers={"Authorization": f"Bearer {self.access_token()}"},
                timeout=30,
            )
            if r.status_code == 401:
                self.token = None
            r.raise_for_status()
            d = r.json()
            items += d.get("items", [])
            page = d.get("nextPageToken")
            if not page:
                return items


def normalize(calendar, e):
    if e.get("status") == "cancelled":
        return None
    if any(a.get("self") and a.get("responseStatus") == "declined" for a in e.get("attendees", [])):
        return None
    start, end = parse_time(e["start"]), parse_time(e["end"])
    return {
        "id": e["id"],
        "calendar": calendar,
        "summary": e.get("summary", ""),
        "start": start.isoformat(),
        "end": end.isoformat(),
        "allDay": "date" in e["start"],
        "location": e.get("location"),
        "meet": e.get("hangoutLink"),
        "url": e.get("htmlLink"),
    }


def triggers(ev):
    if ev["allDay"]:
        return []
    start, end = datetime.fromisoformat(ev["start"]), datetime.fromisoformat(ev["end"])
    return [("soon", start - SOON), ("start", start), ("end", end)]


class Bus:
    def __init__(self):
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="calbus")
        self.client.will_set("calendar/status", "offline", qos=1, retain=True)
        self.client.on_connect = self.on_connect
        self.client.reconnect_delay_set(1, 30)
        self.client.connect_async(BROKER, PORT)
        self.client.loop_start()

    def on_connect(self, client, userdata, flags, reason, properties):
        log(f"connected to mqtt://{BROKER}:{PORT} ({reason})")
        client.publish("calendar/status", "online", qos=1, retain=True)

    def publish(self, topic, payload, retain=False):
        self.client.publish(topic, json.dumps(payload), qos=1, retain=retain)


def load_state():
    try:
        with open(STATE_FILE) as f:
            s = json.load(f)
        return s.get("events", []), set(s.get("fired", []))
    except (OSError, ValueError):
        return [], set()


def save_state(events, fired):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"events": events, "fired": sorted(fired)}, f)
    os.replace(tmp, STATE_FILE)


def run():
    google = Google()
    bus = Bus()
    events, fired = load_state()
    next_poll = datetime.min.replace(tzinfo=timezone.utc)
    last_upcoming = last_now = None
    log(f"watching {', '.join(CALENDARS)}")
    while True:
        now = datetime.now(timezone.utc)
        if now >= next_poll:
            next_poll = now + POLL
            try:
                fresh = []
                for cal in CALENDARS:
                    fresh += [ev for ev in (normalize(cal, e) for e in google.events(cal, now - timedelta(days=1), now + HORIZON)) if ev]
                fresh.sort(key=lambda ev: ev["start"])
                if fresh != events:
                    log(f"{len(fresh)} events in the next {HORIZON.days} days")
                events = fresh
            except Exception as ex:
                log(f"poll failed: {ex}")

        dirty = False
        for ev in events:
            for kind, when in triggers(ev):
                key = f"{ev['id']}|{kind}|{when.isoformat()}"
                if when > now or key in fired:
                    continue
                fired.add(key)
                dirty = True
                if now - when <= GRACE:
                    log(f"{kind}: {ev['summary']}")
                    bus.publish(f"calendar/{kind}", {**ev, "kind": kind})

        upcoming = [ev for ev in events if datetime.fromisoformat(ev["end"]) > now]
        current = [ev for ev in upcoming if datetime.fromisoformat(ev["start"]) <= now]
        if upcoming != last_upcoming:
            bus.publish("calendar/upcoming", upcoming, retain=True)
            last_upcoming = upcoming
            dirty = True
        if current != last_now:
            bus.publish("calendar/now", current, retain=True)
            last_now = current

        if dirty:
            cutoff = now - timedelta(days=2)
            fired = {k for k in fired if datetime.fromisoformat(k.rsplit("|", 1)[1]) > cutoff}
            save_state(events, fired)
        time.sleep(TICK)


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "run":
        run()
    elif len(sys.argv) >= 3 and sys.argv[1] == "auth":
        auth(sys.argv[2])
    else:
        sys.exit("usage: calbus run | calbus auth <client_secret.json>")


if __name__ == "__main__":
    main()
