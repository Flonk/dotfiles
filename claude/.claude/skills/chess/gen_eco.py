#!/usr/bin/env python3
"""Build eco.json: EPD (placement+side+castling+ep) -> "ECO Name" from lichess TSVs.
Run once via nix-shell; output is vendored so runtime needs no replay."""
import csv, json, pathlib, sys
import chess

here = pathlib.Path(__file__).parent
out = {}
for f in sorted((here / "eco").glob("*.tsv")):
    with open(f, newline="") as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            board = chess.Board()
            for tok in row["pgn"].split():
                if tok[0].isdigit() and "." in tok:
                    continue
                board.push_san(tok)
            out[board.epd()] = f'{row["eco"]} {row["name"]}'
(here / "eco.json").write_text(json.dumps(out))
print(f"{len(out)} positions -> eco.json", file=sys.stderr)
