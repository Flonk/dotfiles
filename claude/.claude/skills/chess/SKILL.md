---
name: chess
description: Render a chess position from a FEN, PGN, or opening name to a PNG board image. Two modes — (1) analyze a position: resulting FEN, move list, opening name, and Stockfish eval with the top 5 lines and a best-move arrow; (2) explore an opening by name (e.g. "render the Najdorf", "show the Rio de Janeiro"): named continuations with a popularity-ranked arrow fan. Use whenever the user gives a FEN/PGN or names an opening to visualize, analyze, or explore.
---

# chess

Two modes:
- **Analyze** a position — `chess_render.py`, input a **FEN** or **PGN** (auto-detected). Board + FEN + eval + lines.
- **Explore** an opening — `explore.py`, input an opening **name**, FEN, or PGN. Board + named continuations.

## Run

Everything runs in one nix-shell. Pass the FEN/PGN as a single argument (quote it):

```
nix-shell -p stockfish python3Packages.chess librsvg --run \
  'python3 .claude/skills/chess/chess_render.py [--no-eval] [--depth N] [--flip] [--out PATH] "<FEN or PGN>"'
```

- Stockfish analysis (eval + top 5 lines + eval bar) runs **by default**, and draws a green arrow for the engine's best move.
- `--no-eval` — skip the engine for a fast board-only render (no STOCKFISH section, no bar, no best-move arrow).
- `--depth N` — search depth (default 18); lower = faster.
- `--arrows 'e2e4,g1f3:red,e4e4:#abc'` — manual arrows, drawn on top of the best-move arrow. Each is `<from><to>[:<color>]`; color is a name (green/red/blue/yellow) or hex, default green; a same-square move like `e4e4` draws a circle highlight. Pair with `--no-eval` to annotate a position with only your own arrows.
- `--flip` — orient from Black's side.
- `--out PATH` — PNG output path (default `$TMPDIR/chess.png`).

The script prints JSON: `{fen, turn, status, opening, moves[], pgn, last_ply, image, eval?, lines?[]}`.
`status` is the result string if the game is over (e.g. `Checkmate, Black wins`, `Draw, stalemate`), else `null`. When the game is over the engine is skipped, so `lines` is absent.

## Present the result

Keep it terse, in **this exact order**:

1. **Stockfish lines** — only if `lines` is present. A bold `**STOCKFISH**` header, then the 5 `lines` **reversed** (worst first, best line last — closest to the board), one per line, plain text (not a table): `<score> <SAN PV>`. `score` is White's perspective; `#n` = mate. Omit this whole section if `lines` is absent (game over, or `--no-eval`).
2. **Game** — `**GAME**: <pgn>` inline (plain movetext). Skip the whole line if no moves.
3. **Board PNG** — `SendUserFile` the `image` path.
4. **Summary line** — `**{opening}** — {last_ply} — {last}`, all on one line, where `{last}` is `status` if non-null else `{turn} to Play`. Drop any segment that's `null` (no opening / no `last_ply`) along with its surrounding ` — `.

No FEN line, no headline eval text — the eval number and bar are already in the image.

## Explore mode

For exploring an opening (the user names one, or asks for continuations), use `explore.py` instead:

```
nix-shell -p python3Packages.chess librsvg --run \
  'python3 .claude/skills/chess/explore.py [--flip] [--out PATH] "<opening name | FEN | PGN>"'
```

It resolves a name to a position (shortest matching ECO line), then renders the board with a green **mainline arrow** (drawn last, on top) + up to six faint **blue arrows** (flat 15% opacity) for the next book moves. "Popularity" = how many named ECO lines run through each move (offline proxy; no engine, no network). Output JSON: `{name, fen, turn, last_ply, continuations[], image}` where each continuation is `{san, uci, name, display, count, pct}`, most popular first. `display` is the de-duplicated short name (ECO + distinctive part).

**Present** in this order:
1. A bold `**CONTINUATIONS**` header.
2. The continuations, most-popular first, one per line: `<san> — <display> (<pct>%)`. Mark the first (the green mainline) with a leading `→ `; indent the rest to align.
3. **Board PNG** via `SendUserFile`.
4. **Summary line** — `**{name}** — {last_ply} — {turn} to play`. Drop any `null` segment with its surrounding ` — `.

## Maintenance

`eco/` holds the lichess CC0 opening TSVs. `eco.json` (EPD→name) and `tree.json` (the explorer's precomputed opening tree) are both generated from them so runtime needs no replay — without `tree.json` the explorer would rebuild the tree every call (~1.6 s). Regenerate both only if the TSVs change:

```
nix-shell -p python3Packages.chess --run 'python3 .claude/skills/chess/gen_eco.py'
```
