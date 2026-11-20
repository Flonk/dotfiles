use chrono::{DateTime, FixedOffset, Local, NaiveDate, TimeDelta, TimeZone, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::BTreeSet;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::PathBuf;
use std::process::{exit, Command};
use std::time::{Duration, Instant};
use std::{env, fs, thread};

const SCOPE: &str = "https://www.googleapis.com/auth/calendar.readonly";
const AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";
const API: &str = "https://www.googleapis.com/calendar/v3";
const SECRETS: [&str; 3] = ["client_id", "client_secret", "refresh_token"];
const TICK: Duration = Duration::from_secs(5);

type Time = DateTime<FixedOffset>;

#[derive(Serialize, Deserialize, Clone, PartialEq)]
struct Event {
    id: String,
    calendar: String,
    summary: String,
    start: Time,
    end: Time,
    #[serde(rename = "allDay")]
    all_day: bool,
    location: Option<String>,
    meet: Option<String>,
    url: Option<String>,
}

#[derive(Serialize, Deserialize, Default)]
struct State {
    events: Vec<Event>,
    fired: BTreeSet<String>,
}

enum Failure {
    Unauthorized(String),
    Other(String),
}

impl Failure {
    fn message(&self) -> &str {
        match self {
            Failure::Unauthorized(m) | Failure::Other(m) => m,
        }
    }
}

fn env_or(key: &str, default: &str) -> String {
    env::var(key).ok().filter(|v| !v.is_empty()).unwrap_or_else(|| default.to_string())
}

fn env_num(key: &str, default: i64) -> i64 {
    env_or(key, "").parse().unwrap_or(default)
}

fn read_secret(name: &str) -> Option<String> {
    let path = env::var(format!("CALBUS_{}_FILE", name.to_uppercase())).ok()?;
    let value = fs::read_to_string(path).ok()?.trim().to_string();
    (!value.is_empty()).then_some(value)
}

fn pct(s: &str) -> String {
    s.bytes()
        .map(|b| match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => (b as char).to_string(),
            _ => format!("%{b:02X}"),
        })
        .collect()
}

fn unpct(s: &str) -> String {
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'+' => out.push(b' '),
            b'%' if i + 2 < bytes.len() => {
                match u8::from_str_radix(&s[i + 1..i + 3], 16) {
                    Ok(b) => {
                        out.push(b);
                        i += 2;
                    }
                    Err(_) => out.push(b'%'),
                }
            }
            b => out.push(b),
        }
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn random_hex() -> String {
    let mut buf = [0u8; 16];
    fs::File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut buf)).expect("urandom");
    buf.iter().map(|b| format!("{b:02x}")).collect()
}

fn client_from_file(path: &str) -> (String, String) {
    let raw: Value = serde_json::from_str(&fs::read_to_string(path).unwrap_or_else(|e| {
        eprintln!("cannot read {path}: {e}");
        exit(1)
    }))
    .unwrap_or_else(|e| {
        eprintln!("invalid client json: {e}");
        exit(1)
    });
    let c = raw.get("installed").or_else(|| raw.get("web")).unwrap_or(&raw);
    match (c["client_id"].as_str(), c["client_secret"].as_str()) {
        (Some(id), Some(secret)) => (id.to_string(), secret.to_string()),
        _ => {
            eprintln!("client json has no client_id/client_secret");
            exit(1)
        }
    }
}

fn auth(client_path: Option<&str>) {
    let (id, secret) = match client_path {
        Some(path) => client_from_file(path),
        None => match (read_secret("client_id"), read_secret("client_secret")) {
            (Some(id), Some(secret)) => (id, secret),
            _ => {
                eprintln!("No OAuth client in sops yet. Download the Desktop app client JSON from the Google Cloud console and run: skynet calendar auth <file.json>");
                exit(1)
            }
        },
    };
    let (id, secret) = (id.as_str(), secret.as_str());

    let listener = TcpListener::bind("127.0.0.1:0").expect("bind");
    let redirect = format!("http://127.0.0.1:{}", listener.local_addr().unwrap().port());
    let state = random_hex();
    let url = format!(
        "{AUTH_URL}?client_id={}&redirect_uri={}&response_type=code&scope={}&access_type=offline&prompt=consent&state={state}",
        pct(id),
        pct(&redirect),
        pct(SCOPE)
    );
    eprintln!("Opening the Google consent page. If no browser opens, visit:\n{url}");
    let _ = Command::new("xdg-open").arg(&url).spawn();

    let params = loop {
        let Ok((mut stream, _)) = listener.accept() else { continue };
        let mut line = String::new();
        if BufReader::new(&stream).read_line(&mut line).is_err() {
            continue;
        }
        let query = line.split_whitespace().nth(1).and_then(|p| p.split_once('?')).map(|(_, q)| q).unwrap_or("");
        let params: Vec<(String, String)> = query
            .split('&')
            .filter_map(|kv| kv.split_once('='))
            .map(|(k, v)| (unpct(k), unpct(v)))
            .collect();
        let _ = stream.write_all(
            b"HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nConnection: close\r\n\r\ncalbus is authorized, you can close this tab.",
        );
        if params.iter().any(|(k, _)| k == "code" || k == "error") {
            break params;
        }
    };
    let get = |key: &str| params.iter().find(|(k, _)| k == key).map(|(_, v)| v.clone());
    if let Some(err) = get("error") {
        eprintln!("Google refused: {err}");
        exit(1)
    }
    if get("state").as_deref() != Some(state.as_str()) {
        eprintln!("State mismatch, aborting.");
        exit(1)
    }
    let code = get("code").unwrap();
    let resp = ureq::post(TOKEN_URL).send_form(&[
        ("code", &code),
        ("client_id", id),
        ("client_secret", secret),
        ("redirect_uri", &redirect),
        ("grant_type", "authorization_code"),
    ]);
    let token: Value = match resp {
        Ok(r) => r.into_json().expect("token json"),
        Err(e) => {
            eprintln!("token exchange failed: {e}");
            exit(1)
        }
    };
    let Some(refresh) = token["refresh_token"].as_str() else {
        eprintln!("Google returned no refresh token.");
        exit(1)
    };
    println!("{}", json!({ "client_id": id, "client_secret": secret, "refresh_token": refresh }));
}

struct Google {
    agent: ureq::Agent,
    creds: Vec<Option<String>>,
    token: Option<(String, Instant)>,
}

impl Google {
    fn new() -> Self {
        Google {
            agent: ureq::AgentBuilder::new().timeout(Duration::from_secs(30)).build(),
            creds: Vec::new(),
            token: None,
        }
    }

    fn access_token(&mut self) -> Result<String, Failure> {
        let creds: Vec<Option<String>> = SECRETS.iter().map(|n| read_secret(n)).collect();
        if creds != self.creds {
            self.creds = creds.clone();
            self.token = None;
        }
        if let Some((t, until)) = &self.token {
            if Instant::now() < *until {
                return Ok(t.clone());
            }
        }
        let (Some(id), Some(secret), Some(refresh)) = (&creds[0], &creds[1], &creds[2]) else {
            return Err(Failure::Unauthorized("not authorized, run `skynet calendar auth`".into()));
        };
        let resp = self.agent.post(TOKEN_URL).send_form(&[
            ("client_id", id),
            ("client_secret", secret),
            ("refresh_token", refresh),
            ("grant_type", "refresh_token"),
        ]);
        let body: Value = match resp {
            Ok(r) => r.into_json().map_err(|e| Failure::Other(e.to_string()))?,
            Err(ureq::Error::Status(400, r)) => {
                let v: Value = r.into_json().unwrap_or_default();
                return Err(if v["error"] == "invalid_grant" {
                    Failure::Unauthorized("refresh token revoked or expired, run `skynet calendar auth`".into())
                } else {
                    Failure::Other(format!("token refresh: {v}"))
                });
            }
            Err(e) => return Err(Failure::Other(e.to_string())),
        };
        let token = body["access_token"].as_str().ok_or_else(|| Failure::Other("no access_token".into()))?.to_string();
        let ttl = body["expires_in"].as_u64().unwrap_or(3600).saturating_sub(60);
        self.token = Some((token.clone(), Instant::now() + Duration::from_secs(ttl)));
        Ok(token)
    }

    fn events(&mut self, calendar: &str, from: Time, to: Time) -> Result<Vec<Value>, Failure> {
        let url = format!("{API}/calendars/{}/events", pct(calendar));
        let (from, to) = (from.to_rfc3339(), to.to_rfc3339());
        let mut items = Vec::new();
        let mut page: Option<String> = None;
        loop {
            let auth = format!("Bearer {}", self.access_token()?);
            let mut req = self
                .agent
                .get(&url)
                .set("Authorization", &auth)
                .query("timeMin", &from)
                .query("timeMax", &to)
                .query("singleEvents", "true")
                .query("orderBy", "startTime")
                .query("maxResults", "250");
            if let Some(p) = &page {
                req = req.query("pageToken", p);
            }
            let body: Value = match req.call() {
                Ok(r) => r.into_json().map_err(|e| Failure::Other(e.to_string()))?,
                Err(ureq::Error::Status(401, _)) => {
                    self.token = None;
                    return Err(Failure::Other("access token rejected".into()));
                }
                Err(e) => return Err(Failure::Other(e.to_string())),
            };
            if let Some(list) = body["items"].as_array() {
                items.extend(list.iter().cloned());
            }
            page = body["nextPageToken"].as_str().map(String::from);
            if page.is_none() {
                return Ok(items);
            }
        }
    }
}

fn parse_time(t: &Value) -> Option<Time> {
    if let Some(dt) = t["dateTime"].as_str() {
        return DateTime::parse_from_rfc3339(dt).ok();
    }
    let date = NaiveDate::parse_from_str(t["date"].as_str()?, "%Y-%m-%d").ok()?;
    Local.from_local_datetime(&date.and_hms_opt(0, 0, 0)?).earliest().map(|d| d.fixed_offset())
}

fn normalize(calendar: &str, e: &Value) -> Option<Event> {
    if e["status"] == "cancelled" {
        return None;
    }
    let declined = e["attendees"]
        .as_array()
        .is_some_and(|a| a.iter().any(|x| x["self"] == true && x["responseStatus"] == "declined"));
    if declined {
        return None;
    }
    let s = |k: &str| e[k].as_str().map(String::from);
    Some(Event {
        id: s("id")?,
        calendar: calendar.to_string(),
        summary: s("summary").unwrap_or_default(),
        start: parse_time(&e["start"])?,
        end: parse_time(&e["end"])?,
        all_day: e["start"].get("date").is_some(),
        location: s("location"),
        meet: s("hangoutLink"),
        url: s("htmlLink"),
    })
}

fn remaining_length(mut n: usize) -> Vec<u8> {
    let mut out = Vec::new();
    loop {
        let mut b = (n % 128) as u8;
        n /= 128;
        if n > 0 {
            b |= 0x80;
        }
        out.push(b);
        if n == 0 {
            return out;
        }
    }
}

fn mqtt_str(s: &[u8]) -> Vec<u8> {
    let mut out = (s.len() as u16).to_be_bytes().to_vec();
    out.extend_from_slice(s);
    out
}

fn packet(kind: u8, body: Vec<u8>) -> Vec<u8> {
    let mut out = vec![kind];
    out.extend(remaining_length(body.len()));
    out.extend(body);
    out
}

struct Bus {
    addr: String,
    stream: Option<TcpStream>,
    status: String,
}

impl Bus {
    fn connect(&mut self) -> std::io::Result<()> {
        let mut stream = TcpStream::connect(&self.addr)?;
        stream.set_write_timeout(Some(Duration::from_secs(5)))?;
        stream.set_read_timeout(Some(Duration::from_secs(5)))?;
        let mut body = mqtt_str(b"MQTT");
        body.extend([4, 0x02 | 0x04 | 0x20, 0, 0]);
        body.extend(mqtt_str(b"calbus"));
        body.extend(mqtt_str(b"calendar/status"));
        body.extend(mqtt_str(b"offline"));
        stream.write_all(&packet(0x10, body))?;
        let mut ack = [0u8; 4];
        stream.read_exact(&mut ack)?;
        if ack[0] != 0x20 || ack[3] != 0 {
            return Err(std::io::Error::other(format!("connack refused: {}", ack[3])));
        }
        eprintln!("connected to mqtt://{}", self.addr);
        self.stream = Some(stream);
        let status = self.status.clone();
        self.send("calendar/status", status.as_bytes(), true)
    }

    fn send(&mut self, topic: &str, payload: &[u8], retain: bool) -> std::io::Result<()> {
        let mut body = mqtt_str(topic.as_bytes());
        body.extend_from_slice(payload);
        let pkt = packet(0x30 | retain as u8, body);
        let stream = self.stream.as_mut().ok_or_else(|| std::io::Error::other("not connected"))?;
        stream.write_all(&pkt)
    }

    fn publish(&mut self, topic: &str, payload: &[u8], retain: bool) {
        for _ in 0..2 {
            if self.stream.is_none() {
                if let Err(e) = self.connect() {
                    eprintln!("mqtt connect failed: {e}");
                    self.stream = None;
                    return;
                }
            }
            match self.send(topic, payload, retain) {
                Ok(()) => return,
                Err(_) => self.stream = None,
            }
        }
    }

    fn publish_json<T: Serialize>(&mut self, topic: &str, value: &T, retain: bool) {
        let payload = serde_json::to_vec(value).unwrap_or_default();
        self.publish(topic, &payload, retain);
    }

    fn set_status(&mut self, status: &str) {
        if status != self.status {
            self.status = status.to_string();
            self.publish("calendar/status", status.as_bytes(), true);
        }
    }
}

fn state_file() -> PathBuf {
    let base = env::var("XDG_STATE_HOME")
        .ok()
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(env_or("HOME", "/tmp")).join(".local/state"));
    base.join("calbus/state.json")
}

fn load_state(path: &PathBuf) -> State {
    fs::read_to_string(path).ok().and_then(|s| serde_json::from_str(&s).ok()).unwrap_or_default()
}

fn save_state(path: &PathBuf, state: &State) {
    if let Some(dir) = path.parent() {
        let _ = fs::create_dir_all(dir);
    }
    let tmp = path.with_extension("tmp");
    if fs::write(&tmp, serde_json::to_vec(state).unwrap_or_default()).is_ok() {
        let _ = fs::rename(tmp, path);
    }
}

fn run() {
    let calendars: Vec<String> =
        env_or("CALBUS_CALENDARS", "primary").split(',').filter(|c| !c.is_empty()).map(String::from).collect();
    let soon = TimeDelta::minutes(env_num("CALBUS_SOON_MINUTES", 10));
    let poll = TimeDelta::seconds(env_num("CALBUS_POLL_SECONDS", 60));
    let horizon = TimeDelta::days(7);
    let grace = TimeDelta::minutes(5);
    let path = state_file();

    let mut google = Google::new();
    let mut bus = Bus {
        addr: format!("{}:{}", env_or("CALBUS_BROKER", "127.0.0.1"), env_or("CALBUS_PORT", "1883")),
        stream: None,
        status: "starting".into(),
    };
    bus.publish("calendar/status", b"starting", true);
    let mut state = load_state(&path);
    let mut next_poll = Utc::now().fixed_offset();
    let mut last_upcoming: Option<Vec<Event>> = None;
    let mut last_now: Option<Vec<Event>> = None;
    eprintln!("watching {}", calendars.join(", "));

    loop {
        let now = Utc::now().fixed_offset();
        if now >= next_poll {
            next_poll = now + poll;
            let mut fresh = Vec::new();
            let mut failure = None;
            for cal in &calendars {
                match google.events(cal, now - TimeDelta::days(1), now + horizon) {
                    Ok(items) => fresh.extend(items.iter().filter_map(|e| normalize(cal, e))),
                    Err(f) => {
                        failure = Some(f);
                        break;
                    }
                }
            }
            match failure {
                None => {
                    fresh.sort_by_key(|e| e.start);
                    if fresh != state.events {
                        eprintln!("{} events in the next {} days", fresh.len(), horizon.num_days());
                    }
                    state.events = fresh;
                    bus.set_status("online");
                }
                Some(f) => {
                    eprintln!("poll failed: {}", f.message());
                    bus.set_status(match f {
                        Failure::Unauthorized(_) => "unauthorized",
                        Failure::Other(_) => "error",
                    });
                }
            }
        }

        let mut dirty = false;
        let mut due = Vec::new();
        for ev in &state.events {
            if ev.all_day {
                continue;
            }
            for (kind, when) in [("soon", ev.start - soon), ("start", ev.start), ("end", ev.end)] {
                let key = format!("{}|{kind}|{}", ev.id, when.to_rfc3339());
                if when > now || state.fired.contains(&key) {
                    continue;
                }
                state.fired.insert(key);
                dirty = true;
                if now - when <= grace {
                    due.push((kind, ev.clone()));
                }
            }
        }
        for (kind, ev) in due {
            eprintln!("{kind}: {}", ev.summary);
            let mut payload = serde_json::to_value(&ev).unwrap_or_default();
            payload["kind"] = json!(kind);
            bus.publish_json(&format!("calendar/{kind}"), &payload, false);
        }

        let upcoming: Vec<Event> = state.events.iter().filter(|e| e.end > now).cloned().collect();
        let current: Vec<Event> = upcoming.iter().filter(|e| e.start <= now).cloned().collect();
        if last_upcoming.as_ref() != Some(&upcoming) {
            bus.publish_json("calendar/upcoming", &upcoming, true);
            last_upcoming = Some(upcoming);
            dirty = true;
        }
        if last_now.as_ref() != Some(&current) {
            bus.publish_json("calendar/now", &current, true);
            last_now = Some(current);
        }

        if dirty {
            let cutoff = now - TimeDelta::days(2);
            state.fired.retain(|k| {
                k.rsplit('|').next().and_then(|t| DateTime::parse_from_rfc3339(t).ok()).is_some_and(|t| t > cutoff)
            });
            save_state(&path, &state);
        }
        thread::sleep(TICK);
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("run") => run(),
        Some("auth") => auth(args.get(2).map(String::as_str)),
        _ => {
            eprintln!("usage: calbus run | calbus auth [client_secret.json]");
            exit(2)
        }
    }
}
