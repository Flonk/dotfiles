---
name: chess
description: Render a chess position from a FEN string or PGN to a PNG board image, with the resulting FEN, the move list, the opening name (ECO), and an optional Stockfish evaluation with the top 5 lines. Use whenever the user gives a FEN/PGN or asks to visualize, analyze, or evaluate a chess position.
---

# chess

Render and analyze a chess position. Input is a **FEN** or a **PGN** (movetext, with or without headers); the script auto-detects which.

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
`status` is the result string if the game is over (e.g. `Checkmate — Black wins`, `Draw — stalemate`), else `null`. When the game is over the engine is skipped, so `lines` is absent.

## Present the result

Keep it terse, in **this exact order**:

1. **Stockfish lines** — only if `lines` is present. A bold `**STOCKFISH**` header, then the 5 `lines` **reversed** (worst first, best line last — closest to the board), one per line, plain text (not a table): `<score> <SAN PV>`. `score` is White's perspective; `#n` = mate. Omit this whole section if `lines` is absent (game over, or `--no-eval`).
2. **Game** — `**GAME**: <pgn>` inline (plain movetext). Skip the whole line if no moves.
3. **Board PNG** — `SendUserFile` the `image` path.
4. **Summary line** — `**{opening}** — {last_ply} — {last}`, all on one line, where `{last}` is `status` if non-null else `{turn} to Play`. Drop any segment that's `null` (no opening / no `last_ply`) along with its surrounding ` — `.

No FEN line, no headline eval text — the eval number and bar are already in the image.

Default to no `--eval` unless the user asks to evaluate/analyze. Scores are White-relative; `#n` means mate in n.

## Maintenance

`eco/` holds the lichess CC0 opening TSVs; `eco.json` is the precomputed EPD→name map used at runtime. Regenerate only if the TSVs change:

```
nix-shell -p python3Packages.chess --run 'python3 .claude/skills/chess/gen_eco.py'
```
