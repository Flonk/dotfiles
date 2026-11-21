use chrono::{DateTime, Local, NaiveDate, NaiveDateTime, NaiveTime, SecondsFormat, TimeDelta, TimeZone};
use croner::Cron;
use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;
use serde_json::{json, Value};
use std::io::{self, ErrorKind, Read, Write};
use std::net::TcpStream;
use std::path::PathBuf;
use std::process::exit;
use std::time::{Duration, Instant};
use std::{env, fs, thread};

const GRACE: i64 = 300;
const MAX_WAIT: Duration = Duration::from_secs(30);
const KEEPALIVE: u16 = 60;

struct Msg {
    topic: String,
    payload: Vec<u8>,
}

struct Mqtt {
    stream: TcpStream,
    last_sent: Instant,
}

fn mqtt_str(s: &[u8]) -> Vec<u8> {
    let mut out = (s.len() as u16).to_be_bytes().to_vec();
    out.extend_from_slice(s);
    out
}

fn packet(kind: u8, body: &[u8]) -> Vec<u8> {
    let mut out = vec![kind];
    let mut n = body.len();
    loop {
        let mut b = (n % 128) as u8;
        n /= 128;
        if n > 0 {
            b |= 0x80;
        }
        out.push(b);
        if n == 0 {
            break;
        }
    }
    out.extend_from_slice(body);
    out
}

fn broker() -> String {
    format!(
        "{}:{}",
        env::var("T3CRON_BROKER").unwrap_or_else(|_| "127.0.0.1".into()),
        env::var("T3CRON_PORT").unwrap_or_else(|_| "1883".into())
    )
}

impl Mqtt {
    fn connect(client_id: &str, will: Option<(&str, &[u8])>) -> io::Result<Self> {
        let mut stream = TcpStream::connect(broker())?;
        stream.set_write_timeout(Some(Duration::from_secs(5)))?;
        stream.set_read_timeout(Some(Duration::from_secs(5)))?;
        let mut body = mqtt_str(b"MQTT");
        let flags = 0x02 | if will.is_some() { 0x04 | 0x20 } else { 0 };
        body.extend([4, flags]);
        body.extend(KEEPALIVE.to_be_bytes());
        body.extend(mqtt_str(client_id.as_bytes()));
        if let Some((topic, payload)) = will {
            body.extend(mqtt_str(topic.as_bytes()));
            body.extend(mqtt_str(payload));
        }
        stream.write_all(&packet(0x10, &body))?;
        let mut ack = [0u8; 4];
        stream.read_exact(&mut ack)?;
        if ack[0] != 0x20 || ack[3] != 0 {
            return Err(io::Error::other(format!("broker refused the connection ({})", ack[3])));
        }
        Ok(Mqtt { stream, last_sent: Instant::now() })
    }

    fn send(&mut self, pkt: &[u8]) -> io::Result<()> {
        self.stream.write_all(pkt)?;
        self.last_sent = Instant::now();
        Ok(())
    }

    fn publish(&mut self, topic: &str, payload: &[u8], retain: bool) -> io::Result<()> {
        let mut body = mqtt_str(topic.as_bytes());
        body.extend_from_slice(payload);
        self.send(&packet(0x30 | retain as u8, &body))
    }

    fn subscribe(&mut self, topics: &[&str]) -> io::Result<()> {
        let mut body = 1u16.to_be_bytes().to_vec();
        for t in topics {
            body.extend(mqtt_str(t.as_bytes()));
            body.push(0);
        }
        self.send(&packet(0x82, &body))
    }

    fn keepalive(&mut self) -> io::Result<()> {
        if self.last_sent.elapsed() >= Duration::from_secs(KEEPALIVE as u64 / 2) {
            self.send(&[0xC0, 0])?;
        }
        Ok(())
    }

    fn poll(&mut self, timeout: Duration) -> io::Result<Option<Msg>> {
        self.stream.set_read_timeout(Some(timeout.max(Duration::from_millis(1))))?;
        let mut first = [0u8; 1];
        match self.stream.read(&mut first) {
            Ok(0) => return Err(io::Error::new(ErrorKind::UnexpectedEof, "broker closed the connection")),
            Ok(_) => {}
            Err(e) if matches!(e.kind(), ErrorKind::WouldBlock | ErrorKind::TimedOut) => return Ok(None),
            Err(e) => return Err(e),
        }
        self.stream.set_read_timeout(Some(Duration::from_secs(5)))?;
        let mut len = 0usize;
        let mut shift = 0;
        loop {
            let mut b = [0u8; 1];
            self.stream.read_exact(&mut b)?;
            len |= ((b[0] & 0x7f) as usize) << shift;
            shift += 7;
            if b[0] & 0x80 == 0 {
                break;
            }
        }
        let mut body = vec![0u8; len];
        self.stream.read_exact(&mut body)?;
        if first[0] >> 4 != 3 || body.len() < 2 {
            return Ok(None);
        }
        let tlen = u16::from_be_bytes([body[0], body[1]]) as usize;
        let qos = (first[0] >> 1) & 3;
        let start = 2 + tlen + if qos > 0 { 2 } else { 0 };
        if body.len() < start {
            return Ok(None);
        }
        Ok(Some(Msg {
            topic: String::from_utf8_lossy(&body[2..2 + tlen]).into_owned(),
            payload: body[start..].to_vec(),
        }))
    }
}

fn parse_duration(s: &str) -> Option<TimeDelta> {
    let mut total = TimeDelta::zero();
    let mut num = String::new();
    let mut any = false;
    for c in s.chars().filter(|c| !c.is_whitespace()) {
        if c.is_ascii_digit() {
            num.push(c);
            continue;
        }
        let n: i64 = num.parse().ok()?;
        num.clear();
        total += match c {
            's' => TimeDelta::seconds(n),
            'm' => TimeDelta::minutes(n),
            'h' => TimeDelta::hours(n),
            'd' => TimeDelta::days(n),
            'w' => TimeDelta::weeks(n),
            _ => return None,
        };
        any = true;
    }
    (any && num.is_empty()).then_some(total)
}

fn local(naive: NaiveDateTime) -> Option<DateTime<Local>> {
    Local.from_local_datetime(&naive).earliest()
}

fn parse_at(s: &str, now: DateTime<Local>) -> Option<DateTime<Local>> {
    if let Ok(t) = DateTime::parse_from_rfc3339(s) {
        return Some(t.with_timezone(&Local));
    }
    for fmt in ["%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"] {
        if let Ok(n) = NaiveDateTime::parse_from_str(s, fmt) {
            return local(n);
        }
    }
    if let Ok(d) = NaiveDate::parse_from_str(s, "%Y-%m-%d") {
        return local(d.and_hms_opt(0, 0, 0)?);
    }
    for fmt in ["%H:%M", "%H:%M:%S"] {
        if let Ok(t) = NaiveTime::parse_from_str(s, fmt) {
            let today = local(now.date_naive().and_time(t))?;
            return Some(if today > now { today } else { local((now.date_naive() + TimeDelta::days(1)).and_time(t))? });
        }
    }
    None
}

fn parse_schedule(input: &str, now: DateTime<Local>) -> Result<(String, DateTime<Local>), String> {
    let s = input.trim();
    if let Some(rest) = s.strip_prefix("in ") {
        let d = parse_duration(rest).ok_or_else(|| format!("bad duration '{rest}', use e.g. 10m, 2h, 1h30m, 3d"))?;
        let at = now + d;
        return Ok((format!("at {}", at.to_rfc3339_opts(SecondsFormat::Secs, false)), at));
    }
    let at_input = s.strip_prefix("at ").unwrap_or(s);
    if let Some(at) = parse_at(at_input, now) {
        return Ok((format!("at {}", at.to_rfc3339_opts(SecondsFormat::Secs, false)), at));
    }
    if s.starts_with("at ") {
        return Err(format!("bad time '{at_input}'"));
    }
    let next = cron_next(s, now)?;
    Ok((s.to_string(), next))
}

fn cron_next(expr: &str, after: DateTime<Local>) -> Result<DateTime<Local>, String> {
    let cron = Cron::new(expr).parse().map_err(|e| format!("bad schedule '{expr}': {e}"))?;
    cron.find_next_occurrence(&after, false).map_err(|e| e.to_string())
}

#[derive(Serialize)]
struct Job {
    key: String,
    schedule: String,
    topic: String,
    payload: String,
    next: String,
}

fn db_path() -> PathBuf {
    let base = env::var("XDG_STATE_HOME")
        .ok()
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(env::var("HOME").unwrap_or_else(|_| "/tmp".into())).join(".local/state"));
    base.join("t3cron/jobs.db")
}

fn open_db() -> Connection {
    let path = db_path();
    if let Some(dir) = path.parent() {
        let _ = fs::create_dir_all(dir);
    }
    let db = Connection::open(&path).unwrap_or_else(|e| {
        eprintln!("cannot open {}: {e}", path.display());
        exit(1)
    });
    db.execute_batch(
        "CREATE TABLE IF NOT EXISTS jobs (
            key TEXT PRIMARY KEY,
            schedule TEXT NOT NULL,
            topic TEXT NOT NULL,
            payload TEXT NOT NULL DEFAULT '',
            next INTEGER NOT NULL
        );",
    )
    .expect("schema");
    db
}

fn ts(t: DateTime<Local>) -> i64 {
    t.timestamp()
}

fn from_ts(t: i64) -> DateTime<Local> {
    Local.timestamp_opt(t, 0).single().unwrap_or_else(Local::now)
}

fn all_jobs(db: &Connection) -> Vec<Job> {
    let mut stmt = db.prepare("SELECT key, schedule, topic, payload, next FROM jobs ORDER BY next, key").unwrap();
    stmt.query_map([], |r| {
        Ok(Job {
            key: r.get(0)?,
            schedule: r.get(1)?,
            topic: r.get(2)?,
            payload: r.get(3)?,
            next: from_ts(r.get(4)?).to_rfc3339(),
        })
    })
    .unwrap()
    .filter_map(Result::ok)
    .collect()
}

fn payload_text(v: Option<&Value>) -> String {
    match v {
        None | Some(Value::Null) => String::new(),
        Some(Value::String(s)) => s.clone(),
        Some(other) => other.to_string(),
    }
}

fn key_from(payload: &[u8]) -> Option<String> {
    let text = String::from_utf8_lossy(payload).trim().to_string();
    match serde_json::from_str::<Value>(&text) {
        Ok(Value::Object(o)) => o.get("key").and_then(Value::as_str).map(String::from),
        Ok(Value::String(s)) => Some(s),
        _ => (!text.is_empty()).then_some(text),
    }
}

const LEVELS: [&str; 7] = ["error", "warn", "info", "http", "verbose", "debug", "silly"];

fn event(source: &str, level: &str, attention: bool, description: &str, data: Value) -> Value {
    json!({
        "timestamp": Local::now().to_rfc3339_opts(SecondsFormat::Millis, false),
        "source": source,
        "level": level,
        "attention": attention,
        "description": description,
        "data": data,
    })
}

fn is_event(v: &Value) -> bool {
    v["timestamp"].is_string()
        && v["source"].is_string()
        && v["level"].as_str().is_some_and(|l| LEVELS.contains(&l))
        && v["attention"].is_boolean()
        && v["description"].is_string()
}

fn job_event(key: &str, payload: &str) -> Value {
    match serde_json::from_str::<Value>(payload) {
        Ok(mut v) if is_event(&v) => {
            v["timestamp"] = json!(Local::now().to_rfc3339_opts(SecondsFormat::Millis, false));
            v
        }
        Ok(v) => event("t3cron", "info", false, key, v),
        Err(_) if payload.trim().is_empty() => event("t3cron", "info", false, key, json!({})),
        Err(_) => event("t3cron", "info", false, payload.trim(), json!({ "key": key })),
    }
}

struct Daemon {
    db: Connection,
    bus: Option<Mqtt>,
}

impl Daemon {
    fn publish(&mut self, topic: &str, payload: &[u8], retain: bool) {
        if let Some(bus) = self.bus.as_mut() {
            if let Err(e) = bus.publish(topic, payload, retain) {
                eprintln!("publish to {topic} failed: {e}");
                self.bus = None;
            }
        }
    }

    fn publish_jobs(&mut self) {
        let jobs = serde_json::to_vec(&all_jobs(&self.db)).unwrap_or_default();
        self.publish("cron/jobs", &jobs, true);
    }

    fn error(&mut self, key: Option<&str>, msg: String) {
        eprintln!("{msg}");
        let payload = event("t3cron", "error", false, &msg, json!({ "key": key })).to_string();
        self.publish("cron/error", payload.as_bytes(), false);
    }

    fn fire(&mut self, key: &str, topic: &str, payload: &str) {
        eprintln!("fire {key} -> {topic}");
        let body = job_event(key, payload).to_string();
        self.publish(topic, body.as_bytes(), false);
        let fired = event("t3cron", "verbose", false, &format!("fired {key} -> {topic}"), json!({ "key": key, "topic": topic })).to_string();
        self.publish("cron/fired", fired.as_bytes(), false);
    }

    fn handle(&mut self, msg: Msg) -> bool {
        let now = Local::now();
        match msg.topic.as_str() {
            "cron/set" => {
                let v: Value = match serde_json::from_slice(&msg.payload) {
                    Ok(v) => v,
                    Err(e) => {
                        self.error(None, format!("cron/set: invalid json: {e}"));
                        return false;
                    }
                };
                let (Some(key), Some(schedule), Some(topic)) =
                    (v["key"].as_str(), v["schedule"].as_str(), v["topic"].as_str())
                else {
                    self.error(v["key"].as_str(), "cron/set needs key, schedule and topic".into());
                    return false;
                };
                match parse_schedule(schedule, now) {
                    Ok((schedule, next)) => {
                        self.db
                            .execute(
                                "INSERT INTO jobs (key, schedule, topic, payload, next) VALUES (?1, ?2, ?3, ?4, ?5)
                                 ON CONFLICT(key) DO UPDATE SET schedule = ?2, topic = ?3, payload = ?4, next = ?5",
                                params![key, schedule, topic, payload_text(v.get("payload")), ts(next)],
                            )
                            .expect("upsert");
                        eprintln!("set {key}: {schedule} -> {topic}");
                        true
                    }
                    Err(e) => {
                        self.error(Some(key), e);
                        false
                    }
                }
            }
            "cron/delete" => match key_from(&msg.payload) {
                Some(key) => {
                    let n = self.db.execute("DELETE FROM jobs WHERE key = ?1", params![key]).unwrap_or(0);
                    if n == 0 {
                        self.error(Some(&key), format!("no job '{key}'"));
                    } else {
                        eprintln!("delete {key}");
                    }
                    n > 0
                }
                None => false,
            },
            "cron/run" => {
                let Some(key) = key_from(&msg.payload) else { return false };
                let job: Option<(String, String)> = self
                    .db
                    .query_row("SELECT topic, payload FROM jobs WHERE key = ?1", params![key], |r| Ok((r.get(0)?, r.get(1)?)))
                    .optional()
                    .unwrap_or(None);
                match job {
                    Some((topic, payload)) => self.fire(&key, &topic, &payload),
                    None => self.error(Some(&key), format!("no job '{key}'")),
                }
                false
            }
            _ => false,
        }
    }

    fn fire_due(&mut self) -> bool {
        let now = Local::now();
        let due: Vec<(String, String, String, String, i64)> = {
            let mut stmt = self.db.prepare("SELECT key, schedule, topic, payload, next FROM jobs WHERE next <= ?1").unwrap();
            stmt.query_map(params![ts(now)], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?)))
                .unwrap()
                .filter_map(Result::ok)
                .collect()
        };
        for (key, schedule, topic, payload, next) in &due {
            let one_shot = schedule.starts_with("at ");
            if one_shot || ts(now) - next <= GRACE {
                self.fire(key, topic, payload);
            } else {
                eprintln!("skip {key}, missed by {}s", ts(now) - next);
            }
            if one_shot {
                self.db.execute("DELETE FROM jobs WHERE key = ?1", params![key]).unwrap();
            } else {
                match cron_next(schedule, now) {
                    Ok(n) => {
                        self.db.execute("UPDATE jobs SET next = ?2 WHERE key = ?1", params![key, ts(n)]).unwrap();
                    }
                    Err(e) => {
                        self.db.execute("DELETE FROM jobs WHERE key = ?1", params![key]).unwrap();
                        self.error(Some(key), e);
                    }
                }
            }
        }
        !due.is_empty()
    }

    fn wait(&self) -> Duration {
        let next: Option<i64> = self.db.query_row("SELECT MIN(next) FROM jobs", [], |r| r.get(0)).unwrap_or(None);
        match next {
            Some(n) => Duration::from_secs((n - ts(Local::now())).max(0) as u64).min(MAX_WAIT),
            None => MAX_WAIT,
        }
    }

    fn ensure_bus(&mut self) -> bool {
        if self.bus.is_some() {
            return true;
        }
        let connected = Mqtt::connect("t3cron", Some(("cron/status", b"offline"))).and_then(|mut bus| {
            bus.subscribe(&["cron/set", "cron/delete", "cron/run"])?;
            bus.publish("cron/status", b"online", true)?;
            Ok(bus)
        });
        match connected {
            Ok(bus) => {
                eprintln!("connected to mqtt://{}", broker());
                self.bus = Some(bus);
                self.publish_jobs();
                true
            }
            Err(e) => {
                eprintln!("mqtt connect failed: {e}");
                false
            }
        }
    }

    fn run(&mut self) {
        loop {
            if !self.ensure_bus() {
                if self.fire_due() {
                    self.publish_jobs();
                }
                thread::sleep(Duration::from_secs(5));
                continue;
            }
            if self.fire_due() {
                self.publish_jobs();
            }
            let wait = self.wait();
            let Some(bus) = self.bus.as_mut() else { continue };
            let polled = bus.keepalive().and_then(|_| bus.poll(wait));
            match polled {
                Ok(Some(msg)) => {
                    if self.handle(msg) {
                        self.publish_jobs();
                    }
                }
                Ok(None) => {}
                Err(e) => {
                    eprintln!("mqtt: {e}");
                    self.bus = None;
                }
            }
        }
    }
}

fn cli_bus() -> Mqtt {
    Mqtt::connect(&format!("t3cron-cli-{}", std::process::id()), None).unwrap_or_else(|e| {
        eprintln!("cannot reach the bus at {}: {e}", broker());
        exit(1)
    })
}

fn wait_for<T>(bus: &mut Mqtt, mut check: impl FnMut(&Msg) -> Option<T>) -> Option<T> {
    let deadline = Instant::now() + Duration::from_secs(3);
    while let Some(left) = deadline.checked_duration_since(Instant::now()) {
        match bus.poll(left) {
            Ok(Some(msg)) => {
                if let Some(t) = check(&msg) {
                    return Some(t);
                }
            }
            Ok(None) => {}
            Err(_) => return None,
        }
    }
    None
}

fn jobs_from(msg: &Msg) -> Option<Vec<Value>> {
    if msg.topic != "cron/jobs" {
        return None;
    }
    serde_json::from_slice::<Vec<Value>>(&msg.payload).ok()
}

fn fetch_jobs(bus: &mut Mqtt) -> Vec<Value> {
    wait_for(bus, jobs_from).unwrap_or_else(|| {
        eprintln!("no cron/jobs on the bus, is t3cron running? (systemctl --user status t3cron)");
        exit(1)
    })
}

fn pretty_next(next: &str) -> String {
    DateTime::parse_from_rfc3339(next)
        .map(|t| t.with_timezone(&Local).format("%a %d %b %H:%M").to_string())
        .unwrap_or_else(|_| next.to_string())
}

fn truncate(s: &str, n: usize) -> String {
    if s.chars().count() <= n {
        s.to_string()
    } else {
        s.chars().take(n - 1).collect::<String>() + "…"
    }
}

fn print_jobs(jobs: &[Value]) {
    if jobs.is_empty() {
        println!("no jobs");
        return;
    }
    let rows: Vec<[String; 5]> = jobs
        .iter()
        .map(|j| {
            let s = |k: &str| j[k].as_str().unwrap_or("").to_string();
            let schedule = s("schedule");
            let schedule = if schedule.starts_with("at ") { "once".to_string() } else { schedule };
            [s("key"), pretty_next(&s("next")), schedule, s("topic"), truncate(&s("payload"), 40)]
        })
        .collect();
    let header = ["KEY", "NEXT", "SCHEDULE", "TOPIC", "PAYLOAD"];
    let widths: Vec<usize> =
        (0..5).map(|i| rows.iter().map(|r| r[i].chars().count()).chain([header[i].len()]).max().unwrap()).collect();
    let line = |cells: [&str; 5]| {
        cells.iter().enumerate().map(|(i, c)| format!("{c:<w$}", w = widths[i])).collect::<Vec<_>>().join("  ").trim_end().to_string()
    };
    println!("{}", line(header));
    for r in &rows {
        println!("{}", line([&r[0], &r[1], &r[2], &r[3], &r[4]]));
    }
}

fn usage() -> ! {
    eprintln!(
        "usage: skynet cron [list]
       skynet cron add <key> <schedule> <topic> [payload]
       skynet cron rm <key>
       skynet cron run <key>
       skynet cron watch
       t3bus emit <topic> <level> <description> [--attention] [--data <json>] [--source <name>]

schedule: a cron expression (\"0 9 * * 1-5\", \"*/15 * * * *\", @daily, @hourly)
          or a one-shot: \"in 10m\", \"in 1h30m\", \"at 18:00\", \"at 2026-12-24 18:00\"
levels:   error warn info http verbose debug silly
topics:   cron/set cron/delete cron/run (in), cron/jobs cron/fired cron/error cron/status (out)"
    );
    exit(2)
}

fn cli_add(args: &[String]) {
    if args.len() < 3 {
        usage();
    }
    let (key, schedule, topic) = (&args[0], &args[1], &args[2]);
    let payload = args[3..].join(" ");
    let (schedule, next) = parse_schedule(schedule, Local::now()).unwrap_or_else(|e| {
        eprintln!("{e}");
        exit(1)
    });
    let mut bus = cli_bus();
    bus.subscribe(&["cron/jobs", "cron/error"]).ok();
    let body = json!({ "key": key, "schedule": schedule, "topic": topic, "payload": payload }).to_string();
    bus.publish("cron/set", body.as_bytes(), false).expect("publish");
    let result = wait_for(&mut bus, |m| {
        if m.topic == "cron/error" {
            let v: Value = serde_json::from_slice(&m.payload).ok()?;
            return (v["data"]["key"].as_str() == Some(key.as_str())).then(|| Err(v["description"].as_str().unwrap_or("").to_string()));
        }
        let jobs = jobs_from(m)?;
        jobs.iter().any(|j| j["key"].as_str() == Some(key.as_str()) && j["schedule"].as_str() == Some(schedule.as_str())).then_some(Ok(()))
    });
    match result {
        Some(Ok(())) => println!("{key}: next {} -> {topic}", next.format("%a %d %b %H:%M")),
        Some(Err(e)) => {
            eprintln!("{e}");
            exit(1)
        }
        None => {
            eprintln!("t3cron didn't confirm, is it running? (systemctl --user status t3cron)");
            exit(1)
        }
    }
}

fn cli_rm(args: &[String]) {
    let Some(key) = args.first() else { usage() };
    let mut bus = cli_bus();
    let jobs = {
        bus.subscribe(&["cron/jobs"]).ok();
        fetch_jobs(&mut bus)
    };
    if !jobs.iter().any(|j| j["key"].as_str() == Some(key.as_str())) {
        eprintln!("no job '{key}'");
        exit(1)
    }
    bus.publish("cron/delete", key.as_bytes(), false).expect("publish");
    let gone = wait_for(&mut bus, |m| jobs_from(m).filter(|jobs| !jobs.iter().any(|j| j["key"].as_str() == Some(key.as_str()))));
    match gone {
        Some(_) => println!("removed {key}"),
        None => {
            eprintln!("t3cron didn't confirm the removal");
            exit(1)
        }
    }
}

fn cli_run(args: &[String]) {
    let Some(key) = args.first() else { usage() };
    let mut bus = cli_bus();
    bus.subscribe(&["cron/fired", "cron/error"]).ok();
    bus.publish("cron/run", key.as_bytes(), false).expect("publish");
    let result = wait_for(&mut bus, |m| {
        let v: Value = serde_json::from_slice(&m.payload).ok()?;
        if v["data"]["key"].as_str() != Some(key.as_str()) {
            return None;
        }
        Some(if m.topic == "cron/fired" { Ok(v["data"]["topic"].as_str().unwrap_or("").to_string()) } else { Err(v["description"].as_str().unwrap_or("").to_string()) })
    });
    match result {
        Some(Ok(topic)) => println!("fired {key} -> {topic}"),
        Some(Err(e)) => {
            eprintln!("{e}");
            exit(1)
        }
        None => {
            eprintln!("t3cron didn't confirm, is it running?");
            exit(1)
        }
    }
}

fn cli_watch() {
    let mut bus = cli_bus();
    bus.subscribe(&["cron/fired", "cron/error"]).expect("subscribe");
    loop {
        let _ = bus.keepalive();
        match bus.poll(Duration::from_secs(10)) {
            Ok(Some(m)) => {
                let v: Value = serde_json::from_slice(&m.payload).unwrap_or_default();
                let when = Local::now().format("%H:%M:%S");
                if m.topic == "cron/fired" {
                    println!("{when}  fired  {}  -> {}", v["data"]["key"].as_str().unwrap_or("?"), v["data"]["topic"].as_str().unwrap_or("?"));
                } else {
                    println!("{when}  error  {}  {}", v["data"]["key"].as_str().unwrap_or("-"), v["description"].as_str().unwrap_or("?"));
                }
            }
            Ok(None) => {}
            Err(e) => {
                eprintln!("{e}");
                exit(1)
            }
        }
    }
}

fn cli_emit(args: &[String]) {
    let mut attention = false;
    let mut data = json!({});
    let mut source = env::var("T3_BUS_SOURCE")
        .ok()
        .filter(|s| !s.is_empty())
        .or_else(|| env::var("T3_AGENT").ok().filter(|s| !s.is_empty()).map(|a| format!("claude/{a}")))
        .unwrap_or_else(|| "cli".into());
    let mut positional = Vec::new();
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--attention" | "-a" => attention = true,
            "--data" | "-d" => {
                let raw = it.next().unwrap_or_else(|| usage());
                data = serde_json::from_str(raw).unwrap_or_else(|e| {
                    eprintln!("--data is not json: {e}");
                    exit(1)
                });
            }
            "--source" | "-s" => source = it.next().unwrap_or_else(|| usage()).clone(),
            _ => positional.push(a.clone()),
        }
    }
    if positional.len() < 3 {
        usage();
    }
    let (topic, level) = (&positional[0], positional[1].as_str());
    if !LEVELS.contains(&level) {
        eprintln!("level must be one of: {}", LEVELS.join(" "));
        exit(1)
    }
    let description = positional[2..].join(" ");
    let body = event(&source, level, attention, &description, data).to_string();
    let mut bus = cli_bus();
    bus.publish(topic, body.as_bytes(), false).expect("publish");
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let rest = args.get(1..).unwrap_or(&[]);
    match args.first().map(String::as_str) {
        Some("daemon") => Daemon { db: open_db(), bus: None }.run(),
        None | Some("list") | Some("ls") => {
            let mut bus = cli_bus();
            bus.subscribe(&["cron/jobs"]).ok();
            print_jobs(&fetch_jobs(&mut bus));
        }
        Some("add") | Some("set") => cli_add(rest),
        Some("rm") | Some("remove") | Some("delete") => cli_rm(rest),
        Some("run") => cli_run(rest),
        Some("watch") => cli_watch(),
        Some("emit") => cli_emit(rest),
        _ => usage(),
    }
}
