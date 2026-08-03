---
name: spotify
description: Read and curate Flo's Spotify library via the Web API — list playlists, dump contents, set covers, and run "promote liked" (move all Liked Songs into the monthly playlist under Errthang/Mine/Monthly/yyyy/yyyy-MM). Flo creates the playlists himself in his client; this never creates one. Handles its own OAuth (browser click once, refresh token in gnome-keyring, auto-refreshed after that). Use when Flo asks about his Spotify playlists, what's in a playlist, says "promote liked", or wants to authenticate/re-authenticate the Spotify CLI.
---

# spotify

CLI at `.claude/skills/spotify/spotify_cli.py`. Talks to the Spotify Web API with Flo's own OAuth app.

Credentials come from sops (`nixos/assets/secrets/secrets.json`, wired in `nixos/modules/leisure/spotify/home.nix`), decrypted at rebuild to `/run/user/$UID/secrets{,.d/<gen>}/spotify_client_{id,secret}`. The CLI resolves either layout.

## Run

```
nix-shell -p python3 --run 'python3 .claude/skills/spotify/spotify_cli.py <command>'
```

`cover` additionally needs Pillow: `nix-shell -p python3 python3Packages.pillow`.

The nix-shell banner goes to **stderr**, so `2>/dev/null` gives clean JSON on stdout. Do not pipe through `tail -n +2` — that eats the opening `[`.

## Commands

- `auth [--force] [--timeout N]` — OAuth flow. Prints an authorize URL, serves `127.0.0.1:8888/callback`, stores the refresh token in gnome-keyring. No-op if already authenticated unless `--force`.
- `playlists [--limit N] [--json]` — every playlist Flo owns or follows, paginated. Shows track count, owner, visibility, id.
- `tracks <playlist> [--limit N] [--json]` — a playlist's contents. Accepts a bare id, `spotify:playlist:…`, or an open.spotify.com URL.
- `find <name>` — print the id of the playlist Flo owns with that exact name. Exits 1 if there is none, and refuses if the name is ambiguous.
- `cover <playlist> [--color #121212] [--file F] [--size 640]` — set the cover image. Default is the solid `#121212` the monthlies use.
- `mixtape <YYYY-MM> [--dry-run]` — copy the monthly `yyyy-MM` into `yyyy-MM-mixtape` and cover the year's `yyyy-yyyy-yyyy` separator. Both must already exist; it lists what's missing and stops. Verifies every URI landed. Needs Pillow. See [create mixtape](#create-mixtape).
- `move-likes <playlist> [--month YYYY-MM] [--dry-run]` — add Liked Songs to a playlist, verify every URI landed, then unlike only the verified ones. Idempotent: skips tracks already in the destination, so a retry after a failure never duplicates.

Two cover generators sit alongside it — see [Cover art](#cover-art).

## Flo creates the playlists, you fill them

**There is no create command and you must never POST `/me/playlists`.** A playlist created through the API is invisible in Flo's desktop client until he restarts it, and folders aren't in the API at all — so every new playlist is his job, made in the client, in the right folder, where it lands correctly and shows up immediately.

When a playlist you need doesn't exist: tell Flo the **exact name** and the **exact folder**, then stop and wait for him to say it's done. Don't work around it, don't rename something else into place, don't drive the browser.

## promote liked

Flo's recurring ritual. "promote liked" means: **move all Liked Songs into the `yyyy-MM` playlist filed under `Errthang/Mine/Monthly/yyyy/`.** Liked Songs ends up empty. If the month's playlist doesn't exist yet, Flo makes it — see step 1.

Run as often as Flo likes — several times a month is normal. Repeat runs append to the same month's playlist rather than making a second one.

The library tree (folders are **client-side only**, and Flo maintains them — see below):

```
Errthang
└── Mine
    ├── Monthly
    │   ├── 2021 … 2026          ← year folders, one playlist per month inside
    │   └── MONTHLY-MONTHLY-MONTHLY   ← marker playlist, not a real monthly
    └── Mixtapes
        └── 2021 … 2025          ← year folders, one `yyyy-MM-mixtape` per month
            └── yyyy-yyyy-yyyy   ← divider playlist, INSIDE its year folder
```

The `yyyy-yyyy-yyyy` dividers live **inside** the matching year folder, not at the Mixtapes top level.

### Procedure

`MONTH` is the **current** month: `date +%Y-%m` (e.g. `2026-07`). `YEAR` is its first four characters (`2026`). Only use a different month if Flo says so explicitly.

Run every command from the repo root. **Do not skip a numbered step, and stop at any step that fails** — later steps assume earlier ones succeeded.

**1. Find the month's playlist.** Promoting several times a month is normal — the monthly accumulates.

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py find '2026-07'" 2>/dev/null
```

- **Prints an id** → that's `<ID>`, every later step needs it. Continue.
- **`no playlist named …`, exit 1** → the month hasn't been started. **STOP and ask Flo to make it**, quoting both the name and the folder:

  > Make a playlist called `2026-07` in `Errthang/Mine/Monthly/2026`, and *Add to profile*. Say when it's there.

  Wait for him, then re-run this step. **Never create it yourself** — see [Flo creates the playlists](#flo-creates-the-playlists-you-fill-them).
- **Refuses as ambiguous** → **STOP** and ask Flo which to use. Duplicates mean something went wrong earlier.

**2. Set the cover.** Solid `#121212`, so it's safe to redo on every promotion — and a client-made playlist starts with no cover at all. Note this shell has `pillow` in it; the others don't:

```
nix-shell -p python3 python3Packages.pillow --run "python3 .claude/skills/spotify/spotify_cli.py cover <ID>"
```

Expect `uploaded (202) 640x640 to <ID>`.

**3. Count what will move.**

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py move-likes <ID> --dry-run"
```

Prints `N liked, N eligible`. Note the number and **continue straight to step 4 — do not stop to ask.** Once the playlist exists, the rest runs unattended; Flo asked for it that way.

The protection against a bad move is structural, not a confirmation prompt: `move-likes` adds everything first, re-reads the destination, and unlikes **only** the URIs it confirmed landed there. If `N` is 0, there is nothing to do — say so and stop.

**4. Move the tracks.**

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py move-likes <ID>"
```

Expect `added N`, `verified N/N present in destination`, `unliked N`. If `verified` is less than `N`, the CLI already refused to unlike the shortfall — report exactly which tracks it named.

**5. Verify, then report.** On a repeat promotion the playlist total will be higher than `N` — it already held earlier tracks. What must match is that it grew by `N`.

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py tracks <ID> --limit 5"
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py move-likes <ID> --dry-run"
```

The first must show the same `N` as step 3; the second must say `0 liked`. Tell Flo both numbers and the playlist URL.

**Why the cover goes first:** it overwrites the mosaic Spotify auto-generates once tracks land, so doing it before the move keeps that from ever flashing up.

## create mixtape

"create mixtape" means: **copy every track from the monthly `yyyy-MM` into `yyyy-MM-mixtape`, which sits under `Errthang/Mine/Mixtapes/yyyy/`.** The monthly is left untouched — this is a copy, not a move.

**No cover at this stage.** The cover needs the three artist names, which do not exist until Flo has finished culling. Do not invent one.

```
nix-shell -p python3 python3Packages.pillow --run \
  "python3 .claude/skills/spotify/spotify_cli.py mixtape 2025-03"
```

The command, in order: resolves the monthly, the `yyyy-MM-mixtape` and the year's `yyyy-yyyy-yyyy` separator by exact name; **stops if any is missing**, listing each one and the folder it belongs in; renders the separator's cover if it has none; copies every non-local URI; re-reads the destination and verifies all of them landed. Pillow is required because of the separator cover. `--dry-run` prints the track count and writes nothing.

Just relay the missing list to Flo verbatim and wait. In a fresh year that's two playlists — the mixtape and the separator — both in `Errthang/Mine/Mixtapes/yyyy`, plus *Add to profile* on each. In a year that already has a separator it's just the one. Re-run once he confirms.

Re-running is safe: it skips URIs already in the destination, so it tops up rather than duplicating.

## finalize mixtape

**Flo culls the playlist down to his top ~10 himself, then hands over three artist names.** Never pick the tracks or the artists — wait for him to name them.

Given the names, generate the cover and upload it:

```
nix-shell -p python3 python3Packages.pillow --run \
  "python3 .claude/skills/spotify/mixtape_cover.py 2025-03 --artists Thys Machinedrum Oppidan"
nix-shell -p python3 python3Packages.pillow --run \
  "python3 .claude/skills/spotify/spotify_cli.py cover <ID> --file 2025-03-mixtape.png"
```

The strip color comes from the year in `yyyy-MM`, so it always matches that year's separator. Show Flo the rendered PNG before uploading if there is any doubt about spelling or ordering — the names go on the cover verbatim, in the order given.

## Cover art

Two generators, both writing a 640×640 PNG for `cover --file`. Runnable from any directory:

```
python3 separator_cover.py <year> [--hue H] [--font F] [--size N] [--out F]
python3 mixtape_cover.py <yyyy-MM> --artists A [B …] [same options]
```

**The color of the year.** One hue per year at fixed `S=0.415, V=0.559` (HSV), golden-angle spaced so consecutive years land maximally far apart on the wheel:

```
hue(y) = (358.19 + 137.50776 × (y − 2025)) mod 360
```

Both generators derive it from the year — never pass `--hue` unless Flo asks for a specific one.

**Layout constants** (fractions of canvas, measured off the originals — don't re-derive):

| | separator | mixtape |
|---|---|---|
| background | year color | `#121212`, year-color strip 6.25% tall on top |
| text | `#121212`, centered | `#6c6c6c`, bottom-left |
| cap height | 15.33% | 6.33% |
| position | center x, 49.17% y | 30px left, baseline 608px @ 640 |
| line pitch | — | 1.753 × cap height |

Mixtape names take a trailing period (`Thys.`). Any count works — 2022-05 has one name. If the longest line would breach the side margins the type shrinks until it fits, pitch scaling with it.

**Font.** `CircularSpotifyText-Bold.otf` in the skill folder.

## Folders and library order are not in the API

There is no endpoint to create a folder, list folders, read which folder a playlist is in, or reorder playlists. To the Web API, Flo's library is a flat unordered bag — hence the divider playlists, and hence Flo doing the creating. Don't go looking; it has been [open since 2017](https://github.com/spotify/web-api/issues/1031).

The internal `POST spclient.wg.spotify.com/playlist/v2/user/{user}/rootlist/changes` does expose folders. **Don't.** It needs a web-session credential rather than the OAuth token, and non-public endpoints cut against the developer terms Flo's app registration runs under. The Chrome extension blocks reading page session tokens anyway — do not route around that.

Driving the web player's sidebar with a script used to be how this worked (`file_into_folder.js`, removed August 2026). Don't rebuild it: it broke on every Spotify deploy, and a playlist created over the API still didn't appear in the desktop client until a restart, so Flo ended up restarting anyway.

## API quirks (verified live — the docs and every tutorial are wrong)

The [February 2026 overhaul](https://developer.spotify.com/documentation/web-api/references/changes/february-2026) moved a batch of endpoints. **Deprecated paths return `403 Forbidden`, not `404`** — so every one of these looks like a missing scope and isn't. Never respond to a 403 here by adding scopes.

| Old path (403s) | Current path |
|---|---|
| `GET/POST /playlists/{id}/tracks` | `/playlists/{id}/items` |
| `DELETE /me/tracks` | `DELETE /me/library?uris=…` (max **40** per call, `spotify:track:` URIs) |

Shape changes in the same release:

- Playlist track count is `items.total`, **not** `tracks.total`. `track_total()` accepts either.
- Playlist entries wrap the payload in `item`, not `track`. Worse: inside that payload there IS a `track` key holding the boolean `true` (a type discriminator). Reaching for `track` silently yields `None` or a bool, so the list comes back **empty with no error**. `playlist_item()` handles both shapes and type-checks.
- `POST /playlists/{id}/items` still takes `{"uris": [...]}`, max 100 per call.

## Destructive-operation rule

Anything that removes tracks **must add to the destination, verify every URI landed, and only then remove from the source** — and must only unlike the URIs it actually confirmed. Spotify has no per-track undo and no bulk re-like. `move-likes` implements this; don't write a shortcut that trusts the add succeeded.

This ordering already paid off once: the unlike stage hit a 403 mid-run and nothing was lost, because verification gates the destructive half.

## Auth flow

`auth` blocks until the callback lands, so **run it as a background task** and read the output file for the URL — then hand that URL to Flo to click. Do not click it for him; the consent is his to give.

After the first click there's no browser step again: only the refresh token is persisted, and every command exchanges it for a fresh access token, so nothing expires mid-use. If Spotify rotates the refresh token the CLI stores the new one.

Scopes: `playlist-read-private`, `playlist-read-collaborative`, `playlist-modify-private`, `playlist-modify-public`, `user-library-read`, `user-library-modify`, `user-follow-read`, `user-follow-modify`, `user-top-read`, `user-read-recently-played`, `ugc-image-upload`. Playback scopes are deliberately excluded — this is a library tool, not a remote control. Adding a command that needs a new scope means editing `SCOPES` and re-running `auth --force`.

Search needs no scope at all (`/v1/search` is public catalog data); `genre:`, `label:`, `year:` are query syntax, not permissions.

## Notes

- Keyring entry is service `spotify-cli`, key `refresh_token` (`secret-tool lookup service spotify-cli key refresh_token`).
- Revoke at https://www.spotify.com/account/apps — deleting the keyring entry alone doesn't revoke, it just forces re-auth.
- The app's redirect URI must include `http://127.0.0.1:8888/callback` exactly, or auth fails with `INVALID_CLIENT`.
- `find` and `mixtape` only match playlists Flo **owns**, by exact name — a followed playlist of the same name won't collide.
- `--json` emits the raw Spotify objects, for when the pretty output isn't enough.
