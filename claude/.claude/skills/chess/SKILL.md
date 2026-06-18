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

The script prints JSON: `{fen, turn, opening, moves[], pgn, image, eval?, lines?[]}`.

## Present the result

Render in **this exact order** (this reads best in a chat client):

1. **FEN** — as inline code on its own line.
2. **Best-move table** — only if `--eval`: the top 5 `lines` as a table, `score` (White's perspective; `#n` = mate) + the PV joined as SAN.
3. **PGN** — the full `pgn` movetext inline (no code block), with the turn numbers **bolded**, e.g. `**1.** e4 e5 **2.** Nf3 Nc6 …`. Skip if no moves.
4. **Board PNG** — `SendUserFile` the `image` path.
5. **Last moves** — the last 5 plies of the game on one line (for quick context under the board), e.g. `… 6. Re1 b5 7. Bb3 d6`. Skip if the game is ≤5 plies (the full PGN above already covers it).
6. **Side to move** — `**{turn} to Play**`.
7. **Opening** — the `opening` string in **bold**. Skip if `null`.

The eval number and bar are baked into the image, so don't restate the headline eval as text.

Default to no `--eval` unless the user asks to evaluate/analyze. Scores are White-relative; `#n` means mate in n.

## Maintenance

`eco/` holds the lichess CC0 opening TSVs; `eco.json` is the precomputed EPD→name map used at runtime. Regenerate only if the TSVs change:

```
nix-shell -p python3Packages.chess --run 'python3 .claude/skills/chess/gen_eco.py'
```
