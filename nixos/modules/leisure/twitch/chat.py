import os

os.environ.setdefault("ESCDELAY", "25")

import curses
import json
import queue
import random
import socket
import subprocess
import sys
import textwrap
import threading
import time
from datetime import datetime, timezone

channel = sys.argv[1].lstrip("#").lower()
events = queue.Queue()
info = {}
info_lock = threading.Lock()
recent = []
recent_lock = threading.Lock()

HELP = [
    "/title TEXT       set the stream title (bare /title shows it)",
    "/category NAME    search and set the category, alias /game",
    "/tags A, B, C     set the stream tags (bare /tags shows them)",
    "/info             refresh the status line",
    "/claude TEXT      ask the chat-mod agent (it can run title, category, tags, say and mod actions)",
    "!TEXT             same as /claude, /claude reset starts a fresh conversation",
    "/clear            clear the chat view",
    "/quit             leave (Esc works too)",
    "anything else is sent to chat",
]


def tags_of(raw):
    out = {}
    for part in raw.lstrip("@").split(";"):
        key, _, value = part.partition("=")
        out[key] = value
    return out


def irc():
    while True:
        try:
            sock = socket.create_connection(("irc.chat.twitch.tv", 6667), timeout=600)
            sock.sendall(f"CAP REQ :twitch.tv/tags twitch.tv/commands\r\nNICK justinfan{random.randint(10000, 99999)}\r\nJOIN #{channel}\r\n".encode())
            buf = b""
            while True:
                data = sock.recv(4096)
                if not data:
                    break
                buf += data
                while b"\r\n" in buf:
                    raw, buf = buf.split(b"\r\n", 1)
                    line = raw.decode("utf-8", "replace")
                    if line.startswith("PING"):
                        sock.sendall(("PONG" + line[4:] + "\r\n").encode())
                    elif " 366 " in line:
                        events.put(("sys", f"connected to #{channel}"))
                    elif " PRIVMSG #" in line and line.startswith("@"):
                        tagpart, _, rest = line.partition(" ")
                        tags = tags_of(tagpart)
                        prefix, _, msg = rest.partition(f" PRIVMSG #{channel} :")
                        name = tags.get("display-name") or prefix.lstrip(":").split("!")[0]
                        badges = tags.get("badges", "")
                        mark = "◆ " if "broadcaster" in badges else "⚔ " if "moderator" in badges else "★ " if "subscriber" in badges else ""
                        if msg.startswith("\x01ACTION ") and msg.endswith("\x01"):
                            msg = "* " + msg[8:-1]
                        events.put(("msg", mark + name, tags.get("color", ""), msg))
                        with recent_lock:
                            recent.append(f"[{tags.get('id', '?')}] {name}: {msg}")
                            del recent[:-40]
                    elif " CLEARCHAT " in line or " CLEARMSG " in line:
                        events.put(("sys", "a moderator removed messages"))
            sock.close()
        except OSError as e:
            events.put(("sys", f"chat disconnected ({e}), reconnecting"))
        time.sleep(3)


def twitch(*args):
    result = subprocess.run(["t3os", "twitch", *args], capture_output=True, text=True)
    out = (result.stdout or "").strip()
    err = (result.stderr or "").strip()
    return result.returncode == 0, out, err or out or "failed"


def refresh():
    ok, out, _ = twitch("info")
    if ok:
        try:
            data = json.loads(out)
        except ValueError:
            return
        with info_lock:
            info.clear()
            info.update(data)
        events.put(("tick",))


def poll():
    while True:
        refresh()
        time.sleep(30)


def run(label, *args):
    ok, out, err = twitch(*args)
    if ok:
        events.put(("sys", f"{label}: {out}" if out else label))
        refresh()
    else:
        events.put(("err", err))


def command(text):
    name, _, arg = text[1:].partition(" ")
    name = name.lower()
    arg = arg.strip()
    if name == "title":
        run("title", "title", *(["--title", arg] if arg else []))
    elif name in ("category", "game"):
        run("category", "category", *([arg] if arg else []))
    elif name == "tags":
        run("tags", "tags", *([arg] if arg else []))
    elif name == "info":
        refresh()
        events.put(("sys", "status refreshed"))
    elif name == "claude":
        ask(arg)
    elif name in ("help", "?"):
        for line in HELP:
            events.put(("sys", line))
    else:
        events.put(("err", f"unknown command /{name}, try /help"))


def ask(text):
    if not text:
        events.put(("err", "tell the agent what to do, e.g. !set the title to chill coding"))
        return
    events.put(("sys", "claude is on it…"))
    with recent_lock:
        context = "\n".join(recent)
    result = subprocess.run(["t3os", "twitch", "claude", text], input=context, capture_output=True, text=True)
    if result.returncode == 0:
        events.put(("agent", result.stdout.strip() or "done"))
        refresh()
    else:
        events.put(("err", (result.stderr or result.stdout).strip() or "the agent failed"))


def send(text):
    ok, _, err = twitch("say", text)
    if not ok:
        events.put(("err", err))


def status_line():
    with info_lock:
        d = dict(info)
    if not d:
        return "loading channel info…", False
    parts = []
    if d.get("live"):
        up = ""
        if d.get("started_at"):
            secs = int((datetime.now(timezone.utc) - datetime.fromisoformat(d["started_at"].replace("Z", "+00:00"))).total_seconds())
            up = f" {secs // 3600}:{secs // 60 % 60:02d}"
        parts.append(f"● LIVE{up} · {d.get('viewers', 0)} viewers")
    else:
        parts.append("○ offline")
    parts.append(d.get("title") or "no title")
    if d.get("category"):
        parts.append(d["category"])
    if d.get("tags"):
        parts.append("#" + " #".join(d["tags"]))
    return "  ·  ".join(parts), bool(d.get("live"))


def xterm(hexcolor):
    try:
        r, g, b = (int(hexcolor[i:i + 2], 16) for i in (1, 3, 5))
    except ValueError:
        return -1
    if max(r, g, b) < 60:
        r, g, b = (min(255, c + 90) for c in (r, g, b))

    def level(c):
        return 0 if c < 48 else 1 if c < 115 else (c - 35) // 40

    return 16 + 36 * level(r) + 6 * level(g) + level(b)


def main(scr):
    curses.curs_set(1)
    curses.use_default_colors()
    scr.nodelay(True)
    scr.keypad(True)
    pairs = {}
    colorful = curses.has_colors() and curses.COLORS >= 256

    def pair(hexcolor):
        if not colorful or not hexcolor:
            return 0
        idx = xterm(hexcolor)
        if idx < 0:
            return 0
        if idx not in pairs:
            if len(pairs) + 4 >= curses.COLOR_PAIRS:
                return 0
            curses.init_pair(len(pairs) + 4, idx, -1)
            pairs[idx] = len(pairs) + 4
        return curses.color_pair(pairs[idx])

    if colorful:
        curses.init_pair(1, 244, -1)
        curses.init_pair(2, 196, -1)
        curses.init_pair(3, 135, -1)
    dim = curses.color_pair(1) if colorful else curses.A_DIM
    red = curses.color_pair(2) if colorful else curses.A_BOLD
    purple = curses.color_pair(3) if colorful else curses.A_BOLD
    lines = []
    draft = ""
    scroll = 0
    last_minute = ""
    threading.Thread(target=irc, daemon=True).start()
    threading.Thread(target=poll, daemon=True).start()
    events.put(("sys", f"joining #{channel} · enter sends · /help for commands · pgup/pgdn scroll · esc quits"))

    while True:
        dirty = False
        while not events.empty():
            ev = events.get()
            if ev[0] != "tick":
                lines.append((time.strftime("%H:%M"), ev))
                lines = lines[-2000:]
            dirty = True
        if time.strftime("%H:%M") != last_minute:
            last_minute = time.strftime("%H:%M")
            dirty = True
        try:
            key = scr.get_wch()
        except curses.error:
            key = None
        if key is not None:
            dirty = True
            if key == "\x1b":
                return
            if key in ("\n", "\r", curses.KEY_ENTER):
                text = draft.strip()
                draft = ""
                scroll = 0
                if text in ("/quit", "/exit"):
                    return
                if text == "/clear":
                    lines = []
                elif text.startswith("!"):
                    threading.Thread(target=ask, args=(text[1:].strip(),), daemon=True).start()
                elif text.startswith("/"):
                    threading.Thread(target=command, args=(text,), daemon=True).start()
                elif text:
                    threading.Thread(target=send, args=(text,), daemon=True).start()
            elif key in (curses.KEY_BACKSPACE, "\x7f", "\b"):
                draft = draft[:-1]
            elif key == "\x15":
                draft = ""
            elif key == curses.KEY_PPAGE:
                scroll += 10
            elif key == curses.KEY_NPAGE:
                scroll = max(0, scroll - 10)
            elif isinstance(key, str) and key.isprintable():
                draft += key
        if not dirty:
            time.sleep(0.03)
            continue

        h, w = scr.getmaxyx()
        if h < 5 or w < 20:
            continue
        scr.erase()
        status, live = status_line()
        scr.addnstr(0, 0, status, w - 1, (red if live else purple) | curses.A_BOLD)
        scr.hline(1, 0, curses.ACS_HLINE, w)
        rows = []
        for stamp, ev in lines:
            if ev[0] == "msg":
                _, name, color, msg = ev
                head = f"{stamp} {name}: "
                body = textwrap.wrap(msg, max(10, w - len(head) - 1)) or [""]
                rows.append([(stamp + " ", dim), (name, pair(color) | curses.A_BOLD), (": " + body[0], 0)])
                rows += [[(" " * len(head) + extra, 0)] for extra in body[1:]]
            elif ev[0] == "agent":
                head = f"{stamp} claude: "
                body = textwrap.wrap(ev[1], max(10, w - len(head) - 1)) or [""]
                rows.append([(stamp + " ", dim), ("claude", purple | curses.A_BOLD), (": " + body[0], purple)])
                rows += [[(" " * len(head) + extra, purple)] for extra in body[1:]]
            else:
                attr = red | curses.A_BOLD if ev[0] == "err" else dim
                for part in textwrap.wrap(f"{stamp} {ev[1]}", max(10, w - 1)):
                    rows.append([(part, attr)])
        view = h - 4
        scroll = min(scroll, max(0, len(rows) - view))
        shown = rows[max(0, len(rows) - view - scroll):len(rows) - scroll]
        for y, row in enumerate(shown):
            x = 0
            for text, attr in row:
                if x >= w - 1:
                    break
                scr.addnstr(y + 2, x, text, w - 1 - x, attr)
                x += len(text)
        scr.hline(h - 2, 0, curses.ACS_HLINE, w)
        prompt = "› "
        visible = draft[-(w - len(prompt) - 1):]
        scr.addnstr(h - 1, 0, prompt + visible, w - 1, purple if draft.startswith(("/", "!")) else 0)
        scr.move(h - 1, min(w - 1, len(prompt) + len(visible)))
        scr.refresh()


try:
    curses.wrapper(main)
except KeyboardInterrupt:
    pass
