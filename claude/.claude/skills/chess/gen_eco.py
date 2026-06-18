#!/usr/bin/env python3
"""Build the vendored lookup files from the lichess ECO TSVs (run once via
nix-shell; outputs are committed so runtime needs no replay):

  eco.json   EPD (placement+side+castling+ep) -> "ECO Name"
  tree.json  parent EPD -> [[san, uci, count, name], ...]  (opening explorer)
             count = how many named lines run through the move (popularity);
             name  = the resulting opening's name (resolved here, not at runtime)
"""
import csv, json, pathlib, sys
from collections import Counter, defaultdict
import chess

here = pathlib.Path(__file__).parent
eco = {}
edges = defaultdict(dict)  # parent_epd -> uci -> {san, child, count, names}

for f in sorted((here / "eco").glob("*.tsv")):
    with open(f, newline="") as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            board = chess.Board()
            for tok in row["pgn"].split():
                if tok[0].isdigit() and "." in tok:
                    continue
                parent = board.epd()
                mv = board.parse_san(tok)
                uci, san = mv.uci(), board.san(mv)
                board.push(mv)
                e = edges[parent].get(uci)
                if e is None:
                    e = edges[parent][uci] = {"san": san, "child": board.epd(),
                                              "count": 0, "names": Counter()}
                e["count"] += 1
                e["names"][row["name"]] += 1
            eco[board.epd()] = f'{row["eco"]} {row["name"]}'

tree = {}
for parent, mvs in edges.items():
    tree[parent] = [
        [e["san"], uci, e["count"],
         eco.get(e["child"]) or e["names"].most_common(1)[0][0]]
        for uci, e in mvs.items()]

(here / "eco.json").write_text(json.dumps(eco))
(here / "tree.json").write_text(json.dumps(tree))
print(f"{len(eco)} positions -> eco.json; {len(tree)} nodes -> tree.json", file=sys.stderr)
