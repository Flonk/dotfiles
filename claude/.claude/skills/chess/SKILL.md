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
  'python3 .claude/skills/chess/chess_render.py [--eval] [--depth N] [--flip] [--out PATH] "<FEN or PGN>"'
```

- `--eval` — add Stockfish eval + top 5 lines, and draw a lichess-style eval bar on the left of the board. Costs think-time (depth-bound); omit for an instant board.
- `--depth N` — search depth for `--eval` (default 18).
- `--flip` — orient from Black's side.
- `--out PATH` — PNG output path (default `$TMPDIR/chess.png`).

The script prints JSON: `{fen, opening, moves[], pgn, image, eval?, lines?[]}`.

## Present the result

1. First print **one code block**, each on its own line (omit a line if `null`/empty):
   ```
   <opening>
   <pgn>
   <fen>
   ```
2. Then **send the board PNG** to the user with `SendUserFile` (the `image` path) — after the code block.
3. If `--eval` was used, follow with the **top 5 lines** as a table — `score` (White's perspective; `#n` = mate) and the PV joined as SAN. The eval number and bar are already in the image, so don't restate the headline eval separately.

Default to no `--eval` unless the user asks to evaluate/analyze. Scores are White-relative; `#n` means mate in n.

## Maintenance

`eco/` holds the lichess CC0 opening TSVs; `eco.json` is the precomputed EPD→name map used at runtime. Regenerate only if the TSVs change:

```
nix-shell -p python3Packages.chess --run 'python3 .claude/skills/chess/gen_eco.py'
```
