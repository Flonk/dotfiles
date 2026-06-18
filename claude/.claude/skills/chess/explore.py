#!/usr/bin/env python3
"""Opening explorer. Input a FEN, PGN, or an opening *name* ("Rio de Janeiro").
Renders the board with named continuations instead of engine lines: a green
arrow for the mainline plus up to six blue arrows (fading) for the next book
moves. "Popularity" = how many named ECO lines run through each move.

Run inside: nix-shell -p python3Packages.chess librsvg
"""
import argparse, csv, json, pathlib, re
from collections import Counter, defaultdict
import chess, chess.svg
from chess_render import render_png, ECO, HERE, parse_input

MAIN_COLOR = "#ffcc00e6"   # yellow @ ~0.9 — the mainline
OTHER_COLOR = "#0040c01a"  # blue @ 0.10 — all other continuations

FEN_RE = re.compile(r"^([rnbqkpRNBQKP1-8]+/){7}[rnbqkpRNBQKP1-8]+\s")


def sans_of(pgn_field):
    return [t for t in pgn_field.split() if not (t[0].isdigit() and "." in t)]


def build_tree():
    """parent_epd -> {uci: {san, uci, child, count, names}} over all ECO lines."""
    edges = defaultdict(dict)
    for f in sorted((HERE / "eco").glob("*.tsv")):
        with open(f, newline="") as fh:
            for row in csv.DictReader(fh, delimiter="\t"):
                b = chess.Board()
                for tok in sans_of(row["pgn"]):
                    parent = b.epd()
                    mv = b.parse_san(tok)
                    uci, san = mv.uci(), b.san(mv)
                    b.push(mv)
                    e = edges[parent].get(uci)
                    if e is None:
                        e = {"san": san, "uci": uci, "child": b.epd(),
                             "count": 0, "names": Counter()}
                        edges[parent][uci] = e
                    e["count"] += 1
                    e["names"][row["name"]] += 1
    return edges


def continuations(edges, epd, top=7):
    moves = edges.get(epd, {})
    total = sum(e["count"] for e in moves.values()) or 1
    out = []
    for e in sorted(moves.values(), key=lambda e: -e["count"])[:top]:
        name = ECO.get(e["child"]) or e["names"].most_common(1)[0][0]
        out.append({"san": e["san"], "uci": e["uci"], "name": name,
                    "count": e["count"], "pct": round(100 * e["count"] / total)})
    return out


def find_named(query):
    """Shortest ECO line whose name contains the query (case-insensitive)."""
    q = query.lower()
    best = None
    for f in sorted((HERE / "eco").glob("*.tsv")):
        with open(f, newline="") as fh:
            for row in csv.DictReader(fh, delimiter="\t"):
                if q in row["name"].lower():
                    plies = len(sans_of(row["pgn"]))
                    if best is None or plies < best[0]:
                        best = (plies, row)
    return best[1] if best else None


def resolve(query):
    """-> (board, name) from a FEN, PGN, or opening name."""
    first = query.strip().splitlines()[0] if query.strip() else ""
    if FEN_RE.match(first) or re.match(r"^\s*1\.", query):
        board, _ = parse_input(query)
        return board, None
    row = find_named(query)
    if row is None:
        raise SystemExit(f"no opening, FEN or PGN matched: {query!r}")
    board = chess.Board()
    for tok in sans_of(row["pgn"]):
        board.push_san(tok)
    return board, row["name"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("query", help="opening name, FEN, or PGN")
    ap.add_argument("--flip", action="store_true")
    ap.add_argument("--out", default="/tmp/opening.png")
    args = ap.parse_args()

    board, named = resolve(args.query)
    conts = continuations(build_tree(), board.epd())

    arrows = []
    for i, c in enumerate(conts):
        m = chess.Move.from_uci(c["uci"])
        color = MAIN_COLOR if i == 0 else OTHER_COLOR
        arrows.append(chess.svg.Arrow(m.from_square, m.to_square, color=color))

    lastmove = board.peek() if board.move_stack else None
    render_png(board, args.out, args.flip, lastmove, arrows=arrows)

    print(json.dumps({
        "name": named or ECO.get(board.epd()),
        "fen": board.fen(),
        "turn": "White" if board.turn else "Black",
        "continuations": conts,
        "image": str(pathlib.Path(args.out).resolve()),
    }, indent=2))


if __name__ == "__main__":
    main()
