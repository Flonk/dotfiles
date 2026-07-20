---
name: spotify
description: Read and curate Flo's Spotify library via the Web API — list playlists, dump contents, create playlists, set covers, and run "promote liked" (move all Liked Songs into a new monthly playlist under Errthang/Mine/Monthly/yyyy/yyyy-MM). Handles its own OAuth (browser click once, refresh token in gnome-keyring, auto-refreshed after that). Use when Flo asks about his Spotify playlists, what's in a playlist, says "promote liked", or wants to authenticate/re-authenticate the Spotify CLI.
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
- `create <name> [--public] [--description D]` — create a playlist.
- `cover <playlist> [--color #121212] [--file F] [--size 640]` — set the cover image. Default is the solid `#121212` the monthlies use.
- `mixtape <YYYY-MM> [--public] [--dry-run]` — copy the monthly `yyyy-MM` into `yyyy-MM-mixtape`, creating the year's `yyyy-yyyy-yyyy` separator and cover if missing. Verifies every URI landed. Needs Pillow. See [create mixtape](#create-mixtape).
- `move-likes <playlist> [--month YYYY-MM] [--dry-run]` — add Liked Songs to a playlist, verify every URI landed, then unlike only the verified ones. Idempotent: skips tracks already in the destination, so a retry after a failure never duplicates.

Two cover generators sit alongside it. Both need Pillow, both write a 640×640 PNG you then feed to `cover --file`:

- `separator_cover.py <year> [--hue H] [--font F] [--size N] [--out F]` — the `yyyy` divider art (solid year color, black year centered).
- `mixtape_cover.py <yyyy-MM> --artists A [B …] [--hue H] [--font F] [--size N] [--out F]` — the mixtape art (year-color strip on top, artist names bottom-left).

See [Cover art](#cover-art) for the design constants and the hue rule.

## promote liked

Flo's recurring ritual. "promote liked" means: **move all Liked Songs into the `yyyy-MM` playlist filed under `Errthang/Mine/Monthly/yyyy/`, creating it if this is the month's first promotion.** Liked Songs ends up empty.

Run as often as Flo likes — several times a month is normal. Repeat runs append to the same month's playlist rather than making a second one.

The library tree (folders are **client-side only** — see below):

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

The `yyyy-yyyy-yyyy` dividers live **inside** the matching year folder, not at the Mixtapes top level — verified in the sidebar. Getting this wrong is easy and costs a second move.

### Procedure

`MONTH` is the **current** month: `date +%Y-%m` (e.g. `2026-07`). `YEAR` is its first four characters (`2026`). Only use a different month if Flo says so explicitly.

Run every command from the repo root. **Do not skip a numbered step, and stop at any step that fails** — later steps assume earlier ones succeeded.

**0. Does the month's playlist already exist?** Promoting several times a month is normal — the monthly playlist accumulates. Look it up:

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py playlists --json" 2>/dev/null \
  | nix-shell -p jq --run "jq -r '.[] | select(.name==\"2026-07\") | .id'"
```

- **Prints an id** → the playlist exists. Use it as `<ID>` and **skip to step 4**. It is already filed and already has its cover; redoing those would create a duplicate.
- **Prints nothing** → first promotion this month. Continue with step 1.
- **Prints more than one id** → **STOP** and ask Flo which to use. Duplicates mean something went wrong earlier.

**1. Create the playlist.** Substitute the real month:

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py create '2026-07'"
```

Output ends with `created 2026-07 -> <ID>`. **Keep that `<ID>`** — every later step needs it.

**2. Set the cover.** Note this shell has `pillow` in it; the others don't:

```
nix-shell -p python3 python3Packages.pillow --run "python3 .claude/skills/spotify/spotify_cli.py cover <ID>"
```

Expect `uploaded (202) 640x640 to <ID>`.

**3. File it into the folder.** This is browser work — see the section below for the full sequence. Net effect: `filePlaylist('2026-07', '2026')` returns `{action:'moved', ...}`.

If this step fails → **STOP**. Do not run step 5. An unfiled empty playlist is trivial to clean up; 300 tracks stranded in an unfiled playlist is not.

**4. Count what will move.**

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py move-likes <ID> --dry-run"
```

Prints `N liked, N eligible`. Note the number and **continue straight to step 5 — do not stop to ask.** This whole procedure runs unattended; Flo asked for it that way.

The protection against a bad move is structural, not a confirmation prompt: `move-likes` adds everything first, re-reads the destination, and unlikes **only** the URIs it confirmed landed there. If `N` is 0, there is nothing to do — say so and stop.

**5. Move the tracks.**

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py move-likes <ID>"
```

Expect `added N`, `verified N/N present in destination`, `unliked N`. If `verified` is less than `N`, the CLI already refused to unlike the shortfall — report exactly which tracks it named.

**6. Verify, then report.** On a repeat promotion the playlist total will be higher than `N` — it already held earlier tracks. What must match is that it grew by `N`.

```
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py tracks <ID> --limit 5"
nix-shell -p python3 --run "python3 .claude/skills/spotify/spotify_cli.py move-likes <ID> --dry-run"
```

The first must show the same `N` as step 4; the second must say `0 liked`. Tell Flo both numbers and the playlist URL.

**Why this order:** the folder step is UI-only and needs the playlist to exist, so it has to sit in the middle. Filing before moving means a failure costs an empty playlist rather than orphaned tracks.

### Filing it into the folder (scripted — `file_into_folder.js`)

No API exists, so this drives the sidebar context menu. Exact sequence:

1. Invoke the **`claude-in-chrome`** skill first — it loads the browser tools.
2. `pgrep chrome`. Only if nothing is running, launch it: `nohup claude-chrome >/dev/null 2>&1 &` then wait ~6s. (`claude-chrome` fails if Chrome is already up.)
3. `tabs_context_mcp` with `createIfEmpty: true`, then `navigate` that tab to `https://open.spotify.com`.
4. Confirm Flo is logged in — the sidebar shows "Your Library" with his playlists. **If he is not logged in, ask him to log in himself and wait. Never type his credentials.** The desktop app's session does not carry over to the browser.
5. Read `.claude/skills/spotify/file_into_folder.js` and run it via `javascript_tool`, **wrapped in `{ … }`** so its top-level `const`s don't collide if you run it twice. It ends by assigning `globalThis.filePlaylist`.
6. Call it. The second argument is either a `yyyy` string (shorthand for `Errthang/Mine/Monthly/yyyy`) or an explicit folder path array:

```js
await filePlaylist('2026-07', '2026')
await filePlaylist('2025-2025-2025', ['Errthang', 'Mine', 'Mixtapes', '2025'])
// → {action:'moved', folder:'2026', created:false}
// → {action:'moved', folder:'2026', created:true, renamed:true}  (folder didn't exist)
```

The **last** path segment is the destination and gets created if missing; everything before it is drilled through.

7. Screenshot the sidebar and confirm the playlist is nested under the year folder. Do not trust the return value alone.

8. **Add it to Flo's profile — filing is not finished without this.** A filed playlist stays hidden until you do. Open the playlist in full view (`https://open.spotify.com/playlist/<ID>`), click the **`…`** button under the title, click **Add to profile**, and confirm the toast reads *"Playlist is now displayed on your profile."*

Both branches are verified working. It drills every segment but the last, clicks that last folder if present, otherwise clicks **Create folder** in the parent — which creates the folder *and* moves the playlist in one action — then renames `New Folder` to match.

Clicks in this window steal focus to Hyprland workspace 10 unless the `suppress_event = "activatefocus"` rule in `nixos/modules/development/claude-code/home.nix` is active. Warn Flo rather than clicking repeatedly without saying so.

If it throws, the page state is whatever the last step left; re-running is safe (it dismisses stray menus first). Verify the result in the sidebar rather than trusting the return value alone.

**How it works, and what breaks it:**

- Selectors key off `role="menuitem"` and **visible text only**. Spotify's class names are build-hashed (`PQMaFYfZyRAAMjIZ`) and change constantly — never select on them. Sidebar rows are bare `div`s with no role, testid, or href, so they're matched by first text line, narrowest element wins.
- Each submenu mounts a **new** `[role="menu"]`; the deepest is always the last visible one. That's the drilling primitive.
- Hover needs all four of `pointerover`, `mouseover`, `pointermove`, `mousemove`. Fewer and the submenu never opens.
- Waits are **polled, not fixed** — submenus mount lazily and fixed sleeps race.
- After a click-away closes a menu, the next `contextmenu` can be swallowed mid-settle. `openRowMenu` retries 4×, and the menu item is **re-queried after** the retry loop: a node from a superseded attempt is detached, and hovering it fails silently.
- The sidebar is **virtualised** — a playlist that isn't scrolled into view has no DOM node. Freshly created playlists sit at the top, so this rarely bites, but the error message says so explicitly.

When the DOM changes, re-probe with `spotifyDom` (exported: `sidebarRow`, `deepestMenu`, `itemNamed`, `itemsIn`, `waitFor`, `dismissMenus`) and fix the text constants.

Do not fall back to drag-and-drop: it needs the playlist and a three-level-deep folder visible simultaneously, and only works when the sidebar sort is **Custom order**.

**Deleting a folder shows a confirmation reading "delete this folder and all playlists inside".** Only ever confirm one you just created and can see is empty — `2023` has 12 playlists in it and the dialog text is identical. Querying `[role="dialog"]` also matches the page's language picker, so confirm by clicking the visible button, not by DOM-matching the first dialog.

**Ordering caveat:** a freshly touched folder floats to the top of `Monthly` when the sidebar is sorted by **Recents**, which is not where it belongs. Nothing can fix this programmatically — tell Flo to switch the sidebar to **Custom order**, which is also the only mode where manual arrangement sticks.

## create mixtape

"create mixtape" means: **copy every track from the monthly `yyyy-MM` into a new `yyyy-MM-mixtape`, filed under `Errthang/Mine/Mixtapes/yyyy/`.** The monthly is left untouched — this is a copy, not a move.

**No cover at this stage.** The cover needs the three artist names, which do not exist until Flo has finished culling. Do not invent one.

```
nix-shell -p python3 python3Packages.pillow --run \
  "python3 .claude/skills/spotify/spotify_cli.py mixtape 2025-03"
```

The command, in order: resolves the monthly by exact name (bails unless exactly one matches), creates the `yyyy-yyyy-yyyy` separator **and its cover** if that year has none yet, creates `yyyy-MM-mixtape`, copies every non-local URI, re-reads the destination and verifies all of them landed. Pillow is required because of the separator cover. `--dry-run` prints the track count and writes nothing at all.

Re-running is safe: it skips URIs already in the destination, so it tops up rather than duplicating.

It finishes by listing the playlists that still need the browser: file each into `Errthang/Mine/Mixtapes/yyyy`, then **Add to profile** (see step 8 above). A newly created separator needs this too.

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

Two generators, both writing a 640×640 PNG for `cover --file`. Run them from the skill folder — `mixtape_cover.py` imports `separator_cover.py`:

```
nix-shell -p python3 python3Packages.pillow --run "python3 separator_cover.py 2025"
nix-shell -p python3 python3Packages.pillow --run \
  "python3 mixtape_cover.py 2025-03 --artists Thys Machinedrum Oppidan"
```

**The color of the year.** Every year has one hue at fixed `S=0.415, V=0.559` (HSV). Both generators derive it from the year, so never pass `--hue` unless Flo asks for a specific one.

The rule is the golden angle off 2025 red:

```
hue(y) = (358.19 + 137.50776 × (y − 2025)) mod 360
```

Golden-angle spacing is what keeps consecutive years maximally far apart on the wheel instead of drifting into each other.

No lookup table — one formula, all years. It reproduces 2024's `220.68` exactly (2025 was derived from it) but **not** 2021–2023, which Flo picked by eye before the rule existed. That is fine and deliberate: those years are finished, their covers are already uploaded, and no new 2021–2023 mixtapes will ever be made. If one were ever regenerated, pass its measured hue explicitly with `--hue` (`2021: 94.00`, `2022: 264.83`, `2023: 45.76`).

**Layout constants** (fractions of canvas, measured off the originals — don't re-derive):

| | separator | mixtape |
|---|---|---|
| background | year color | `#121212`, year-color strip 6.25% tall on top |
| text | `#121212`, centered | `#6c6c6c`, bottom-left |
| cap height | 15.33% | 6.33% |
| position | center x, 49.17% y | 30px left, baseline 608px @ 640 |
| line pitch | — | 1.753 × cap height |

Mixtape names take a trailing period (`Thys.`). Any count works — 2022-05 has one name. If the longest line would breach the side margins the type shrinks until it fits, pitch scaling with it.

**Font.** `CircularSpotifyText-Bold.otf` in the skill folder, which is what Spotify itself uses. It is a commercial Lineto face — **do not commit it**; it is untracked on purpose. Both scripts fall back to Work Sans Bold from nixpkgs when it is absent, which needs `work-sans` added to the nix-shell (`-p python3 python3Packages.pillow work-sans`) because the sandbox cannot see store paths outside the shell's closure.

## Folders and library order are not in the API

There is no endpoint to create a folder, list folders, read which folder a playlist is in, or reorder playlists in the library. Requested [since 2017](https://github.com/spotify/web-api/issues/1031), still absent after the February 2026 overhaul. To the Web API, Flo's library is a flat unordered bag.

`MONTHLY-MONTHLY-MONTHLY` and the `yyyy-yyyy-yyyy` playlists are dividers Flo made to work around exactly this.

An internal endpoint (`POST spclient.wg.spotify.com/playlist/v2/user/{user}/rootlist/changes`) does expose folders. **Don't.** It needs a web-session credential rather than the OAuth token, it's undocumented and unstable, and using non-public endpoints cuts against the developer terms Flo's app registration runs under. The Chrome extension also blocks reading page session tokens outright — do not try to route around that block.

## API quirks (verified live — the docs and every tutorial are wrong)

The [February 2026 overhaul](https://developer.spotify.com/documentation/web-api/references/changes/february-2026) moved a batch of endpoints. **Deprecated paths return `403 Forbidden`, not `404`** — so every one of these looks like a missing scope and isn't. Never respond to a 403 here by adding scopes.

| Old path (403s) | Current path |
|---|---|
| `GET/POST /playlists/{id}/tracks` | `/playlists/{id}/items` |
| `POST /users/{id}/playlists` | `POST /me/playlists` |
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
- Playlists created via the API land at the **top** of the library and cannot be repositioned programmatically.
- `--json` emits the raw Spotify objects, for when the pretty output isn't enough.
