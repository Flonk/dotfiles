#!/usr/bin/env python3
import argparse
import base64
import glob
import http.server
import json
import os
import re
import secrets as pysecrets
import subprocess
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request

REDIRECT_URI = "http://127.0.0.1:8888/callback"
SCOPES = " ".join(
    [
        "playlist-read-private",
        "playlist-read-collaborative",
        "playlist-modify-private",
        "playlist-modify-public",
        "user-library-read",
        "user-library-modify",
        "user-follow-read",
        "user-follow-modify",
        "user-top-read",
        "user-read-recently-played",
        "ugc-image-upload",
    ]
)
KEYRING_SERVICE = "spotify-cli"
API = "https://api.spotify.com/v1"


def secret_path(name):
    uid = os.getuid()
    direct = f"/run/user/{uid}/secrets/{name}"
    if os.path.exists(direct):
        return direct
    gens = sorted(
        glob.glob(f"/run/user/{uid}/secrets.d/*/{name}"),
        key=lambda p: int(p.split("/")[-2]),
    )
    if not gens:
        sys.exit(f"secret '{name}' not found; is the spotify module rebuilt?")
    return gens[-1]


def read_secret(name):
    with open(secret_path(name)) as f:
        return f.read().strip()


def keyring_get(key):
    r = subprocess.run(
        ["secret-tool", "lookup", "service", KEYRING_SERVICE, "key", key],
        capture_output=True,
        text=True,
    )
    return r.stdout.strip() or None


def keyring_set(key, value):
    subprocess.run(
        [
            "secret-tool",
            "store",
            "--label",
            f"spotify-cli {key}",
            "service",
            KEYRING_SERVICE,
            "key",
            key,
        ],
        input=value,
        text=True,
        check=True,
    )


def basic_auth():
    cid = read_secret("spotify_client_id")
    sec = read_secret("spotify_client_secret")
    return cid, base64.b64encode(f"{cid}:{sec}".encode()).decode()


def post_token(payload):
    _, basic = basic_auth()
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=urllib.parse.urlencode(payload).encode(),
        headers={"Authorization": f"Basic {basic}"},
    )
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def access_token():
    refresh = keyring_get("refresh_token")
    if not refresh:
        sys.exit("not authenticated; run: spotify_cli.py auth")
    try:
        tok = post_token({"grant_type": "refresh_token", "refresh_token": refresh})
    except urllib.error.HTTPError as e:
        if e.code in (400, 401):
            sys.exit("refresh token rejected; run: spotify_cli.py auth")
        raise
    if tok.get("refresh_token"):
        keyring_set("refresh_token", tok["refresh_token"])
    return tok["access_token"]


def api_get(path, token):
    req = urllib.request.Request(
        path if path.startswith("http") else f"{API}{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")[:300]
        if e.code == 403:
            sys.exit(f"403 from spotify (scope missing? re-run auth)\n{body}")
        sys.exit(f"{e.code} from spotify\n{body}")


def paginate(path, token, limit, cap):
    items = []
    url = f"{API}{path}{'&' if '?' in path else '?'}limit={limit}"
    while url:
        page = api_get(url, token)
        items.extend(page["items"])
        if cap and len(items) >= cap:
            return items[:cap], page.get("total", len(items))
        url = page.get("next")
    return items, len(items)


def cmd_auth(args):
    cid, _ = basic_auth()
    if keyring_get("refresh_token") and not args.force:
        print("already authenticated (use --force to redo)")
        return

    state = pysecrets.token_urlsafe(16)
    params = urllib.parse.urlencode(
        {
            "client_id": cid,
            "response_type": "code",
            "redirect_uri": REDIRECT_URI,
            "scope": SCOPES,
            "state": state,
        }
    )
    box = {}
    done = threading.Event()

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if q.get("state", [None])[0] == state and "code" in q:
                box["code"] = q["code"][0]
                body = b"authorized, close this tab"
            else:
                box["error"] = q.get("error", ["state mismatch"])[0]
                body = b"auth failed"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(body)
            done.set()

        def log_message(self, format, *a):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 8888), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    print("CLICK THIS:", flush=True)
    print(f"https://accounts.spotify.com/authorize?{params}\n", flush=True)

    done.wait(timeout=args.timeout)
    server.shutdown()

    if "code" not in box:
        sys.exit(f"auth failed: {box.get('error', 'timeout')}")

    tok = post_token(
        {
            "grant_type": "authorization_code",
            "code": box["code"],
            "redirect_uri": REDIRECT_URI,
        }
    )
    keyring_set("refresh_token", tok["refresh_token"])
    print("authenticated, refresh token stored in keyring")


def track_total(p):
    for k in ("items", "tracks"):
        v = p.get(k)
        if isinstance(v, dict) and "total" in v:
            return v["total"]
    return "?"


def cmd_playlists(args):
    token = access_token()
    items, total = paginate("/me/playlists", token, 50, args.limit)
    if args.json:
        print(json.dumps(items, indent=2))
        return
    print(f"{total} playlists\n")
    for p in items:
        if not p:
            continue
        owner = p.get("owner") or {}
        who = owner.get("display_name") or owner.get("id") or "?"
        vis = "public" if p.get("public") else "private"
        n = track_total(p)
        print(f"{p.get('name') or '(untitled)'}")
        print(f"    {n} tracks · {who} · {vis} · {p.get('id', '?')}")


def playlist_id(raw):
    m = re.search(r"(?:playlist[:/])([A-Za-z0-9]+)", raw)
    return m.group(1) if m else raw


def playlist_item(entry):
    for k in ("item", "track"):
        v = entry.get(k)
        if isinstance(v, dict):
            return v
    return None


def cmd_tracks(args):
    token = access_token()
    pid = playlist_id(args.playlist)
    meta = api_get(f"/playlists/{pid}", token)
    items, _ = paginate(f"/playlists/{pid}/items", token, 100, args.limit)
    if args.json:
        print(json.dumps(items, indent=2))
        return
    print(f"{meta.get('name', '?')} — {track_total(meta)} tracks\n")
    for i, it in enumerate(items, 1):
        t = playlist_item(it)
        if not t:
            continue
        artists = ", ".join(a["name"] for a in t.get("artists", [])) or "?"
        added = (it.get("added_at") or "")[:10]
        print(f"{i:4}. {t.get('name', '?')} — {artists}  [{added}]")


def api_send(path, token, method, payload=None, ctype="application/json"):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        path if path.startswith("http") else f"{API}{path}",
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": ctype},
    )
    try:
        with urllib.request.urlopen(req) as r:
            body = r.read()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} -> {e.code} {e.read().decode(errors='replace')[:250]}")


def chunked(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i : i + n]


def cmd_create(args):
    token = access_token()
    pl = api_send(
        "/me/playlists",
        token,
        "POST",
        {
            "name": args.name,
            "public": args.public,
            "description": args.description or "",
        },
    )
    print(f"created {pl['name']} -> {pl['id']}")
    print(pl["external_urls"]["spotify"])


def owned_named(token, name):
    me = api_get("/me", token)["id"]
    items, _ = paginate("/me/playlists", token, 50, None)
    return [
        p
        for p in items
        if p and p.get("name") == name and (p.get("owner") or {}).get("id") == me
    ]


def playlist_uris(token, pid):
    items, _ = paginate(f"/playlists/{pid}/items", token, 100, None)
    uris = []
    for it in items:
        t = playlist_item(it)
        if isinstance(t, dict) and t.get("uri") and not t.get("is_local"):
            uris.append(t["uri"])
    return uris


def ensure_separator(token, year, public):
    name = f"{year}-{year}-{year}"
    found = owned_named(token, name)
    if len(found) > 1:
        sys.exit(f"{len(found)} playlists named {name}; resolve by hand")
    if found:
        print(f"{name} exists -> {found[0]['id']}")
        return None

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from separator_cover import find_font, hue_for_year, render

    pl = api_send(
        "/me/playlists",
        token,
        "POST",
        {"name": name, "public": public, "description": ""},
    )
    pid = pl["id"]
    print(f"created {name} -> {pid}")
    upload_cover(token, pid, render(str(year), hue_for_year(year), 640, find_font()))
    return pid


def cmd_mixtape(args):
    token = access_token()
    if not re.fullmatch(r"\d{4}-\d{2}", args.month):
        sys.exit("month must look like 2025-03")

    src = owned_named(token, args.month)
    if len(src) != 1:
        sys.exit(f"expected exactly 1 playlist named {args.month}, found {len(src)}")

    name = f"{args.month}-mixtape"
    dst = owned_named(token, name)
    if len(dst) > 1:
        sys.exit(f"{len(dst)} playlists named {name}; resolve by hand")

    uris = playlist_uris(token, src[0]["id"])
    print(f"{args.month}: {len(uris)} tracks to copy")
    if not uris:
        sys.exit("source is empty, nothing to do")
    if args.dry_run:
        print("dry run, nothing written")
        return

    new_separator = ensure_separator(token, args.month[:4], args.public)

    if dst:
        pid = dst[0]["id"]
        print(f"{name} already exists -> {pid}")
    else:
        pl = api_send(
            "/me/playlists",
            token,
            "POST",
            {"name": name, "public": args.public, "description": ""},
        )
        pid = pl["id"]
        print(f"created {name} -> {pid}")

    already = set(playlist_uris(token, pid))
    todo = [u for u in uris if u not in already]
    if already:
        print(f"{len(uris) - len(todo)} already present, skipping those")
    for batch in chunked(todo, 100):
        api_send(f"/playlists/{pid}/items", token, "POST", {"uris": batch})
    print(f"added {len(todo)}")

    landed = set(playlist_uris(token, pid))
    missing = [u for u in uris if u not in landed]
    print(f"verified {len(uris) - len(missing)}/{len(uris)} present in destination")
    if missing:
        sys.exit(f"{len(missing)} failed to land; source playlist untouched")
    print(f"https://open.spotify.com/playlist/{pid}")

    needs_filing = [x for x in (new_separator, None if dst else pid) if x]
    if needs_filing:
        print(f"\nstill to do in the browser, for each of {', '.join(needs_filing)}:")
        print(f"  file into Errthang/Mine/Mixtapes/{args.month[:4]}, then Add to profile")


def cmd_move_likes(args):
    token = access_token()
    pid = playlist_id(args.playlist)

    liked, _ = paginate("/me/tracks", token, 50, None)
    entries = []
    for it in liked:
        t = it.get("track")
        if not isinstance(t, dict) or not t.get("uri"):
            continue
        if t.get("is_local"):
            continue
        if args.month and not (it.get("added_at") or "").startswith(args.month):
            continue
        entries.append((t["uri"], t["id"], t.get("name", "?")))

    skipped = len(liked) - len(entries)
    print(f"{len(liked)} liked, {len(entries)} eligible" + (f", {skipped} skipped (local/unavailable)" if skipped else ""))

    if not entries:
        return
    if args.dry_run:
        print("dry run, nothing written")
        return

    existing, _ = paginate(f"/playlists/{pid}/items", token, 100, None)
    already = set()
    for it in existing:
        t = playlist_item(it)
        if isinstance(t, dict) and t.get("uri"):
            already.add(t["uri"])

    uris = [e[0] for e in entries if e[0] not in already]
    if already:
        print(f"{len(entries) - len(uris)} already in destination, skipping those")
    for batch in chunked(uris, 100):
        api_send(f"/playlists/{pid}/items", token, "POST", {"uris": batch})
    print(f"added {len(uris)} to {pid}")

    present, _ = paginate(f"/playlists/{pid}/items", token, 100, None)
    landed = set()
    for it in present:
        t = playlist_item(it)
        if isinstance(t, dict) and t.get("uri"):
            landed.add(t["uri"])

    confirmed = [e for e in entries if e[0] in landed]
    missing = [e for e in entries if e[0] not in landed]
    print(f"verified {len(confirmed)}/{len(entries)} present in destination")
    if missing:
        print(f"NOT unliking {len(missing)} that failed to land:")
        for _, _, n in missing[:10]:
            print(f"    {n}")
    if not confirmed:
        sys.exit("nothing verified, aborting before any unlike")

    uris_out = [e[0] for e in confirmed]
    done = 0
    for batch in chunked(uris_out, 40):
        q = urllib.parse.urlencode({"uris": ",".join(batch)})
        api_send(f"/me/library?{q}", token, "DELETE")
        done += len(batch)
    print(f"unliked {done}")


def upload_cover(token, pid, im):
    import io

    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=90)
    payload = base64.b64encode(buf.getvalue())
    if len(payload) > 256 * 1024:
        sys.exit(f"encoded image is {len(payload)}B, over spotify's 256KB limit")

    req = urllib.request.Request(
        f"{API}/playlists/{pid}/images",
        data=payload,
        method="PUT",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "image/jpeg",
        },
    )
    try:
        with urllib.request.urlopen(req) as r:
            print(f"uploaded ({r.status}) {im.width}x{im.height} to {pid}")
    except urllib.error.HTTPError as e:
        sys.exit(f"{e.code} {e.read().decode(errors='replace')[:200]}")


def cmd_cover(args):
    from PIL import Image

    token = access_token()
    pid = playlist_id(args.playlist)

    if args.file:
        im = Image.open(args.file).convert("RGB")
    else:
        c = args.color.lstrip("#")
        rgb = tuple(int(c[i : i + 2], 16) for i in (0, 2, 4))
        im = Image.new("RGB", (args.size, args.size), rgb)

    upload_cover(token, pid, im)


p = argparse.ArgumentParser(prog="spotify_cli.py")
sub = p.add_subparsers(dest="cmd", required=True)

a = sub.add_parser("auth", help="run the OAuth flow")
a.add_argument("--force", action="store_true")
a.add_argument("--timeout", type=int, default=600)
a.set_defaults(func=cmd_auth)

pl = sub.add_parser("playlists", help="list your playlists")
pl.add_argument("--limit", type=int)
pl.add_argument("--json", action="store_true")
pl.set_defaults(func=cmd_playlists)

tr = sub.add_parser("tracks", help="list a playlist's contents")
tr.add_argument("playlist", help="playlist id, uri, or url")
tr.add_argument("--limit", type=int)
tr.add_argument("--json", action="store_true")
tr.set_defaults(func=cmd_tracks)

cv = sub.add_parser("cover", help="set a playlist cover image")
cv.add_argument("playlist", help="playlist id, uri, or url")
cv.add_argument("--color", default="#121212", help="solid colour hex (default #121212)")
cv.add_argument("--file", help="use an image file instead of a solid colour")
cv.add_argument("--size", type=int, default=640)
cv.set_defaults(func=cmd_cover)

cr = sub.add_parser("create", help="create a playlist")
cr.add_argument("name")
cr.add_argument("--public", action="store_true")
cr.add_argument("--description", default="")
cr.set_defaults(func=cmd_create)

mx = sub.add_parser("mixtape", help="copy a monthly playlist into yyyy-MM-mixtape")
mx.add_argument("month", help="YYYY-MM of the monthly to copy")
mx.add_argument("--public", action="store_true")
mx.add_argument("--dry-run", action="store_true")
mx.set_defaults(func=cmd_mixtape)

ml = sub.add_parser("move-likes", help="move liked songs into a playlist, then unlike them")
ml.add_argument("playlist", help="destination playlist id, uri, or url")
ml.add_argument("--month", help="only move likes added in YYYY-MM")
ml.add_argument("--dry-run", action="store_true")
ml.set_defaults(func=cmd_move_likes)

args = p.parse_args()
args.func(args)
