---
name: chess
description: Render a chess position from a FEN, PGN, or opening name to a PNG board image, or train on Lichess puzzles. Modes — (1) analyze a position: resulting FEN, move list, opening name, and Stockfish eval with the top 5 lines and a best-move arrow; (2) explore an opening by name (e.g. "render the Najdorf", "show the Rio de Janeiro"): named continuations with a popularity-ranked arrow fan; (3) puzzles: serve a random Lichess puzzle (rating 1800+) to solve, grade the line, and track a personal Elo. Use whenever the user gives a FEN/PGN, names an opening to visualize/analyze/explore, or asks for a chess puzzle / to train.
---

# chess

Three modes:
- **Analyze** a position — `chess_render.py`, input a **FEN** or **PGN** (auto-detected). Board + FEN + eval + lines.
- **Explore** an opening — `explore.py`, input an opening **name**, FEN, or PGN. Board + named continuations.
- **Puzzles** — `puzzles.py`, serve/grade Lichess puzzles with a tracked Elo (see Puzzle mode below).

**Perspective:** if the user asks to see it from Black's side — "as black", "for black", "from black's perspective" — pass `--flip` (works in both scripts) so the board renders with Black at the bottom.

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
3. **Board** — deliver the `image` with `SendUserFile`. (It's a smaller thumbnail than a Read-tool render, but Read images are transcript-bound and don't show cross-device, e.g. laptop → phone; SendUserFile reaches every device.)
4. **Summary line** — `**{opening}** — {last_ply} — {last}`, all on one line, where `{last}` is `status` if non-null else `{turn} to Play`. Drop any segment that's `null` (no opening / no `last_ply`) along with its surrounding ` — `.

No FEN line, no headline eval text — the eval number and bar are already in the image.

**Commentary:** default to none. The lines, board, and summary above stand on their own. If the user asks a question, answer only that, in **one or two sentences of plain factual data** (the move, the eval, the concrete tactical point) — this is the optional kibitz. Never: explain eval-sign conventions or other chess basics, draw "lessons," moralize, replay the game move-by-move, or use emotive/hyperbolic language ("crushing", "monster", "horrible"). The user plays at a competent level. His colour is whichever side the PGN's White/Black header carries his name (`TheFlonk`, sometimes `TheFlonk` variants); if no name is present, take the side he states and don't restate it.

## Explore mode

For exploring an opening (the user names one, or asks for continuations), use `explore.py` instead:

```
nix-shell -p python3Packages.chess librsvg --run \
  'python3 .claude/skills/chess/explore.py [--flip] [--out PATH] "<opening name | FEN | PGN>"'
```

It resolves a name to a position (shortest matching ECO line), then renders the board with a green **mainline arrow** (drawn last, on top) + up to six faint **blue arrows** (flat 15% opacity) for the next book moves. "Popularity" = how many named ECO lines run through each move (offline proxy; no engine, no network). Output JSON: `{name, fen, turn, last_ply, pgn, continuations[], image}` where each continuation is `{san, uci, name, display, count, pct}`, most popular first. `display` is the de-duplicated short name (ECO + distinctive part). `pgn` is the movetext that reached the position.

**Present** in this order:
1. A bold `**CONTINUATIONS**` header.
2. The continuations, most-popular first, one per line: `<san> — <display> (<pct>%)`. Mark the first (the green mainline) with a leading `→ `; indent the rest to align.
3. **Line** — `**LINE**: <pgn>` inline (the movetext that got us here). Skip the line if `pgn` is empty (e.g. starting position).
4. **Board** — deliver the `image` with `SendUserFile` (reaches every device; Read-tool renders are transcript-bound and don't show cross-device).
5. **Summary line** — `**{name}** — {last_ply} — {turn} to play`. Drop any `null` segment with its surrounding ` — `.

## Puzzle mode

For "give me a puzzle" / "let me train" / "next puzzle" / grading an attempt, use `puzzles.py`. Needs `python3Packages.zstandard` for the first download:

```
nix-shell -p python3Packages.chess python3Packages.zstandard librsvg --run \
  'python3 .claude/skills/chess/puzzles.py <next|check|status|build> [args]'
```

Backed by the **Lichess CC0 puzzle DB**. On first `next` it streams `lichess_db_puzzle.csv.zst` and caches a filtered slice (default 50 000 puzzles rated ≥ 1800) under `~/.cache/chess-puzzles/` — never committed, builds once (~30 s). State (Elo, solved/failed IDs, the active puzzle) lives in `state.json` there.

- `next [--min-rating N] [--flip-off]` — pick a random **unsolved** puzzle, render the board (no eval bar, no arrows — nothing that spoils it), and set it active. JSON: `{id, rating, side_to_move, fen, image, your_elo, solved_count, n_solver_moves}`. The board is auto-oriented so the **side to move is at the bottom**.
- `check "<line>"` — grade your solving line for the active puzzle (SAN or UCI, space/comma separated, move numbers and `...` tolerated). Give **only the solver's moves** — the opponent's replies are interleaved automatically. Verdicts: `solved`, `wrong`, `incomplete` (correct so far — keeps the puzzle active, reveals nothing). On a terminal verdict it updates Elo (K=32, expected-score model), files the ID, renders the played-out line, and returns `{verdict, solution, themes, elo_before, elo_after, elo_delta, image}`.
- `status` — `{elo, solved, failed, cached, active_puzzle}`.
- `build [--min-rating N] [--limit N]` — force a (re)build of the cached slice.

**Present a served puzzle (`next`):** show only the board (`SendUserFile`) and a one-line header — `**Puzzle {id}** ({rating}) — **{side_to_move}** to move, {n_solver_moves} move(s) to find — your Elo {your_elo}`. **Reveal nothing else**: no themes, no eval, no hints, no opening name. Then wait for the user's line.

**Present a graded result (`check`):** deliver the solution-line `image`, then one line — `**{verdict}** — solution: {solution} — Elo {elo_before} → {elo_after} ({elo_delta:+})`. For `incomplete`, just say "correct so far — give the full line" and reveal nothing. Themes may be mentioned only after a terminal verdict. Keep the kibitz to the Commentary rule above.

## Maintenance

`eco/` holds the lichess CC0 opening TSVs. `eco.json` (EPD→name) and `tree.json` (the explorer's precomputed opening tree) are both generated from them so runtime needs no replay — without `tree.json` the explorer would rebuild the tree every call (~1.6 s). Regenerate both only if the TSVs change:

```
nix-shell -p python3Packages.chess --run 'python3 .claude/skills/chess/gen_eco.py'
```
